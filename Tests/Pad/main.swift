import AppKit
let p=Pad(frame:NSRect(x:0,y:0,width:400,height:250));p.capturing=true
p.rawTouch(device:1,count:1,id:1,x:0.1,y:0.1);assert(p.points.isEmpty)
p.rawTouch(device:1,count:0,id:0,x:0,y:0)
p.rawTouch(device:1,count:1,id:2,x:0.2,y:0.3);p.rawTouch(device:1,count:1,id:2,x:0.4,y:0.5)
assert(p.points.count==2 && p.touching)
p.rawTouch(device:2,count:0,id:0,x:0,y:0);assert(p.touching)
p.rawTouch(device:1,count:0,id:0,x:0,y:0);assert(!p.touching)
p.rawTouch(device:1,count:1,id:3,x:0.5,y:0.5);assert(p.points.last!.stroke==2)
p.rawTouch(device:1,count:2,id:3,x:0.5,y:0.5);let n=p.points.count
p.rawTouch(device:1,count:1,id:3,x:0.6,y:0.6);assert(p.points.count==n && p.touching)
p.clear();assert(p.points.isEmpty && p.rawAwaitLift)
p.rawTouch(device:1,count:0,id:0,x:0,y:0)
p.rawTouch(device:1,count:1,id:4,x:Double.nan,y:0.4);assert(p.points.isEmpty)
p.capturing=false
p.rawTouch(device:1,count:1,id:5,x:0.3,y:0.3);assert(p.points.isEmpty)
var clearCount=0;p.clearAction={clearCount += 1}
let clear=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"c",charactersIgnoringModifiers:"c",isARepeat:false,keyCode:8)!
p.keyDown(with:clear);assert(clearCount==1)
print("PASS: Pad capture gating, activation lift, multistroke, cross-device isolation, multi-finger rejection, clear, invalid coordinates, actual key dispatch")
