import Foundation
func line(_ coords:[(Double,Double)],stroke:Int=1)->[Point]{var p=[Point]();for i in 1..<coords.count{for j in 0..<20{let t=Double(j)/19;p.append(Point(x:coords[i-1].0+(coords[i].0-coords[i-1].0)*t,y:coords[i-1].1+(coords[i].1-coords[i-1].1)*t,stroke:stroke))}};return p}
let square=line([(0,0),(1,0),(1,1),(0,1),(0,0)])
let triangle=line([(0,0),(0.5,1),(1,0),(0,0)])
let shifted=square.map{Point(x:$0.x*350+70,y:$0.y*350-25,stroke:1)}
let gs=[Gesture(name:"square",app:"/tmp/a.app",samples:[square,square,square]),Gesture(name:"triangle",app:"/tmp/b.app",samples:[triangle,triangle,triangle])]
assert(Recognizer.error(square,shifted)<0.00001)
assert(Recognizer.match(shifted,gs)?.0 == 0)
assert(Recognizer.match(triangle,gs)?.0 == 1)
assert(Recognizer.match(square,[gs[0],gs[0]]) == nil)
assert(Recognizer.match([],gs) == nil)
assert(Recognizer.normalize(Array(repeating:Point(x:1,y:1,stroke:0),count:100)).isEmpty)
let vertical=line([(0,0),(0,1)]);assert(Recognizer.match(vertical,gs) == nil)
let multi=line([(0,0),(0,1)])+line([(1,0),(1,1)],stroke:2)
assert(Recognizer.normalize(multi).count == 64)
let data=try JSONEncoder().encode(gs);let decoded=try JSONDecoder().decode([Gesture].self,from:data);assert(decoded.count == 2 && decoded[0].samples.count == 3)
print("PASS: scale/translation, distinct shapes, ambiguous rejection, empty/degenerate/unknown rejection, multistroke, persistence round trip")
