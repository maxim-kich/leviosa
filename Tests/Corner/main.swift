import Foundation
for corner in 0..<4 {
 var r=CornerGesture();r.corner=corner
 func f(_ u:Double,_ v:Double,_ t:Double,_ n:Int=1)->Bool {let x=corner%2==0 ? u:1-u;let y=corner<2 ? 1-v:v;r.resetOnLift(count:n);return r.feed(count:n,id:1,x:x,y:y,time:t)}
 assert(!f(0.05,0.05,0));assert(f(0.30,0.30,0.3));assert(!f(0.35,0.35,0.4))
 _=f(0,0,2,0);assert(!f(0.5,0.5,2.1));assert(!f(0.7,0.7,2.4))
 _=f(0,0,3,0);assert(!f(0.05,0.05,3.1));assert(!f(0.3,0.3,3.2,2));assert(!f(0.4,0.4,3.3))
 _=f(0,0,4,0);assert(!f(0.05,0.05,4.1));assert(!f(0.4,0.06,4.3))
}
print("PASS: four corners, cooldown, centre start, multi-finger and horizontal rejection")
