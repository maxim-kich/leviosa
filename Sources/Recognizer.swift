import Foundation
struct Point: Codable { var x: Double; var y: Double; var stroke: Int }
struct Gesture: Codable, Identifiable {
 var id: UUID
 var name: String
 var app: String
 var samples: [[Point]]
 init(name:String,app:String,samples:[[Point]],id:UUID=UUID()){self.id=id;self.name=name;self.app=app;self.samples=samples}
 private enum CodingKeys:String,CodingKey {case id,name,app,samples}
 init(from decoder:Decoder)throws{
  let c=try decoder.container(keyedBy:CodingKeys.self)
  id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
  name=try c.decode(String.self,forKey:.name);app=try c.decode(String.self,forKey:.app);samples=try c.decode([[Point]].self,forKey:.samples)
 }
 var appName:String {URL(fileURLWithPath:app).deletingPathExtension().lastPathComponent}
 var displayTitle:String {let title=name.trimmingCharacters(in:.whitespacesAndNewlines);return title.isEmpty ? appName:title}
}
enum Recognizer {
 static func distance(_ a: Point,_ b: Point)->Double { hypot(a.x-b.x,a.y-b.y) }
 // Arc-length resampling preserves pen-up boundaries; translation and uniform scale invariant.
 static func normalize(_ points: [Point])->[Point] {
  guard points.count > 3 else { return [] }
  var lengths=[0.0]
  for i in 1..<points.count { lengths.append(lengths.last! + (points[i].stroke == points[i-1].stroke ? distance(points[i],points[i-1]) : 0)) }
  guard let total=lengths.last, total > 0.0001 else { return [] }
  var out=[Point](); var j=1
  for i in 0..<64 {
   let target=total * Double(i)/63
   while j < points.count-1 && (lengths[j] < target || lengths[j] == lengths[j-1]) { j += 1 }
   let span=lengths[j]-lengths[j-1], t=span > 0 ? max(0,min(1,(target-lengths[j-1])/span)) : 0
   out.append(Point(x:points[j-1].x+(points[j].x-points[j-1].x)*t,y:points[j-1].y+(points[j].y-points[j-1].y)*t,stroke:0))
  }
  let minX=out.map(\.x).min()!, maxX=out.map(\.x).max()!, minY=out.map(\.y).min()!, maxY=out.map(\.y).max()!
  let scale=max(maxX-minX,maxY-minY), cx=out.map(\.x).reduce(0,+)/64, cy=out.map(\.y).reduce(0,+)/64
  return out.map { Point(x:($0.x-cx)/scale,y:($0.y-cy)/scale,stroke:0) }
 }
 static func error(_ a:[Point],_ b:[Point])->Double {
  let a=normalize(a),b=normalize(b); guard a.count == 64,b.count == 64 else{return 100}
  return zip(a,b).map{distance($0,$1)}.reduce(0,+)/64
 }
 static func match(_ points:[Point],_ gestures:[Gesture])->(Int,Double)? {
  let scores=gestures.enumerated().filter{$0.element.samples.count == 3}.map { (i,g) in (i,g.samples.map{error(points,$0)}.sorted().prefix(2).reduce(0,+)/2) }.sorted{$0.1 < $1.1}
  guard let best=scores.first,best.1 < 0.16 else{return nil}
  if scores.count > 1 && scores[1].1-best.1 < 0.045 {return nil}
  return best
 }
}
