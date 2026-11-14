import Foundation
// One contact only, starts in outer 12%, travels inward on both axes.
struct CornerGesture {
 var corner=0
 var origin:(Double,Double,Double,Int)?
 var blocked=false
 var lastFire = -Double.infinity
 mutating func feed(count:Int,id:Int,x:Double,y:Double,time:Double)->Bool {
  guard count == 1 else {origin=nil;blocked=count>1;return false}
  guard !blocked,time-lastFire>1.5,x.isFinite,y.isFinite,(0...1).contains(x),(0...1).contains(y) else{return false}
  let u = corner%2 == 0 ? x : 1-x
  let v = corner<2 ? 1-y : y
  guard let o=origin else{if u<0.12 && v<0.12{origin=(u,v,time,id)};return false}
  let dt=time-o.2,dx=u-o.0,dy=v-o.1
  guard id==o.3,dt<0.65,dx > -0.04,dy > -0.04 else{origin=nil;blocked=true;return false}
  if dt>0.08,dx>0.20,dy>0.20,dx/dy>0.5,dx/dy<2 {lastFire=time;origin=nil;blocked=true;return true}
  return false
 }
 mutating func resetOnLift(count:Int){if count==0{blocked=false;origin=nil}}
}
