import AppKit
let screen=NSRect(x:-1600,y:300,width:1600,height:900)
for corner in 0..<4 {
 let r=overlayFrame(size:NSSize(width:400,height:322),visible:screen,corner:corner)
 assert(screen.contains(r));assert(r.minX == (corner%2==0 ? -1580:-420));assert(r.minY == (corner<2 ? 858:320))
 let huge=overlayFrame(size:NSSize(width:9000,height:9000),visible:screen,corner:corner);assert(screen.contains(huge))
}
print("PASS: four overlay corners, offset displays, visible-frame clamping")
let settings=NSRect(x:-1450,y:420,width:860,height:560)
let recording=recordingOverlayFrame(size:NSSize(width:400,height:250),parent:settings,visible:screen)
assert(recording.midX==settings.midX && recording.midY==settings.midY)
assert(recording.size==NSSize(width:400,height:250))
for parent in [NSRect(x:-2200,y:100,width:860,height:560),NSRect(x:-200,y:1100,width:860,height:560)] {
 let clamped=recordingOverlayFrame(size:NSSize(width:400,height:250),parent:parent,visible:screen)
 assert(screen.insetBy(dx:20,dy:20).contains(clamped))
}
let oversizedRecording=recordingOverlayFrame(size:NSSize(width:9000,height:9000),parent:settings,visible:screen)
assert(screen.insetBy(dx:20,dy:20).contains(oversizedRecording))
print("PASS: recording centers over Settings on its display and clamps to visible bounds")
assert(!OverlayPlacementPolicy.arriving.contains(.canJoinAllSpaces))
assert(OverlayPlacementPolicy.arriving.contains(.moveToActiveSpace))
assert(!OverlayPlacementPolicy.settled.contains(.canJoinAllSpaces))
assert(!OverlayPlacementPolicy.settled.contains(.moveToActiveSpace))
assert(OverlayPlacementPolicy.settled.contains(.fullScreenAuxiliary))
if #available(macOS 13,*){assert(OverlayPlacementPolicy.settled.contains(.canJoinAllApplications))}
print("PASS: arrival uses current Space; active capture stays on one Space with full-screen eligibility")
