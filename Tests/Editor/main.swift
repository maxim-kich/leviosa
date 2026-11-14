import Foundation
func stroke(_ vertices:[(Double,Double)])->[Point] {
    var out=[Point]()
    for i in 1..<vertices.count {for j in 0..<20 {
        let t=Double(j)/19
        out.append(Point(x:vertices[i-1].0+(vertices[i].0-vertices[i-1].0)*t,y:vertices[i-1].1+(vertices[i].1-vertices[i-1].1)*t,stroke:1))
    }}
    return out
}
let square=stroke([(0,0),(1,0),(1,1),(0,1),(0,0)])
let samples=[square,square,square]
let older=Gesture(name:"Older",app:"/Applications/Calculator.app",samples:samples)
let newer=Gesture(name:"Newer",app:"/Applications/Safari.app",samples:samples)
let library=[newer,older]
var draft=GestureDraft()
assert(!draft.canSave && draft.isEmpty)
draft.samples=samples;assert(!draft.canSave)
draft.appPath="/Applications/Preview.app";assert(draft.canSave)
let created=try draft.applying(to:library)
assert(created.count==3 && created[0].displayTitle=="Preview" && created[0].name.isEmpty)
assert(created[1].id==newer.id && created[2].id==older.id && created[0].id != older.id)
draft.samples=Array(samples.prefix(2));assert(!draft.canSave)
draft.samples=Array(repeating:[Point(x:0,y:0,stroke:0)],count:3);assert(!draft.canSave)
print("PASS: optional title, three valid samples and app required, create prepends with a unique identity")

draft.edit(older)
let before=try GestureStore.encode(library)
assert(draft.canSave && draft.visibleGestures(in:library).map(\.id)==[newer.id])
draft.title="  Updated  ";draft.appPath="/Applications/Notes.app"
let edited=try draft.applying(to:library)
assert(edited.count==2 && edited[0].id==older.id && edited[0].name=="Updated" && edited[0].appName=="Notes" && edited[1].id==newer.id)
let afterEdit=try GestureStore.encode(library);assert(afterEdit==before)
draft.cancel();assert(draft.isEmpty && !draft.canSave && draft.visibleGestures(in:library).map(\.id)==library.map(\.id))
draft.edit(older)
do {_ = try draft.applying(to:[newer]);assertionFailure("Editing a deleted item must not silently recreate it")}catch GestureEditError.missingOriginal{}
print("PASS: edit is detached, hides only its row, save moves it first without duplication, cancel restores the exact original")

let temp=FileManager.default.temporaryDirectory.appendingPathComponent("LeviOsa-Editor-"+UUID().uuidString)
try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
defer{try? FileManager.default.removeItem(at:temp)}
let url=temp.appendingPathComponent("gestures.json")
var raw=try JSONSerialization.jsonObject(with:JSONEncoder().encode([older,newer])) as! [[String:Any]]
for i in raw.indices {raw[i].removeValue(forKey:"id")}
let legacy=try JSONSerialization.data(withJSONObject:raw)
try legacy.write(to:url)
let migrated=try GestureStore.load(from:url)
let unchanged=try Data(contentsOf:url);assert(migrated.map(\.name)==["Newer","Older"] && unchanged==legacy)
try GestureStore.save(migrated,to:url)
let reloaded=try GestureStore.load(from:url)
assert(reloaded.map(\.id)==migrated.map(\.id))
let loadedAgain=try GestureStore.load(from:url);assert(loadedAgain.map(\.id)==reloaded.map(\.id))
let json=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [String:Any]
assert(json["version"] as? Int == 2)
do {_ = try GestureStore.decode(Data(#"{"version":99,"gestures":[]}"#.utf8));assertionFailure()}catch GestureEditError.unsupportedVersion{}
print("PASS: legacy append order upgrades once, loading does not rewrite data, ordered schema and stable IDs persist")

var committed=library
draft.edit(older);draft.title="Not committed"
let candidate=try draft.applying(to:committed)
let badDestination=temp.appendingPathComponent("directory")
try FileManager.default.createDirectory(at:badDestination,withIntermediateDirectories:true)
do {try GestureStore.save(candidate,to:badDestination);committed=candidate;assertionFailure()}catch{}
assert(committed.map(\.id)==library.map(\.id) && committed[1].name=="Older")
assert(draft.editingID==older.id && draft.title=="Not committed")
let afterFailure=try GestureStore.encode(committed);assert(afterFailure==before)
print("PASS: failed persistence leaves committed ordering and data intact and keeps the editor draft for retry")
