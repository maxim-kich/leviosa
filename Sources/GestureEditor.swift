// SPDX-License-Identifier: MIT
import Foundation

struct GestureDraft {
    var editingID: UUID?
    var title = ""
    var appPath = ""
    var samples = [[Point]]()
    var canSave: Bool { !appPath.isEmpty && samples.count == 3 && samples.allSatisfy{Recognizer.normalize($0).count == 64} }
    var isEmpty: Bool {editingID == nil && title.isEmpty && appPath.isEmpty && samples.isEmpty}
    mutating func edit(_ gesture:Gesture) {
        editingID=gesture.id;title=gesture.name;appPath=gesture.app;samples=gesture.samples
    }
    mutating func cancel() {self=Self()}
    func applying(to gestures:[Gesture]) throws -> [Gesture] {
        guard canSave else{throw GestureEditError.incomplete}
        if let editingID,!gestures.contains(where:{$0.id == editingID}) {throw GestureEditError.missingOriginal}
        let value=Gesture(name:title.trimmingCharacters(in:.whitespacesAndNewlines),app:appPath,samples:samples,id:editingID ?? UUID())
        return [value]+gestures.filter{$0.id != value.id}
    }
    func visibleGestures(in gestures:[Gesture])->[Gesture] {gestures.filter{$0.id != editingID}}
}
enum GestureEditError:Error {case incomplete,missingOriginal,unsupportedVersion}

enum GestureStore {
    private struct Document:Codable {var version=2;var gestures:[Gesture]}
    static func decode(_ data:Data)throws->[Gesture] {
        // The original prototype appended new gestures. Upgrade to newest-first once.
        if let legacy=try? JSONDecoder().decode([Gesture].self,from:data) {return Array(legacy.reversed())}
        let document=try JSONDecoder().decode(Document.self,from:data)
        guard document.version == 2 else{throw GestureEditError.unsupportedVersion}
        return document.gestures
    }
    static func encode(_ gestures:[Gesture])throws->Data {let encoder=JSONEncoder();encoder.outputFormatting = [.sortedKeys];return try encoder.encode(Document(gestures:gestures))}
    static func load(from url:URL)throws->[Gesture] {
        guard FileManager.default.fileExists(atPath:url.path) else{return []}
        return try decode(Data(contentsOf:url))
    }
    static func save(_ gestures:[Gesture],to url:URL)throws {
        let data=try encode(gestures)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:url,options:.atomic)
    }
}
