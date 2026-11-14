import AppKit
// Screen-local visible bounds, independent of display origins and scale factors.
func overlayFrame(size:NSSize,visible:NSRect,corner:Int)->NSRect {
 let inset:CGFloat=20
 let fitted=NSSize(width:min(size.width,max(1,visible.width-inset*2)),height:min(size.height,max(1,visible.height-inset*2)))
 return NSRect(origin:NSPoint(x:corner%2==0 ? visible.minX+inset:visible.maxX-inset-fitted.width,
               y:corner<2 ? visible.maxY-inset-fitted.height:visible.minY+inset),size:fitted)
}

/// Recording belongs to its Settings window, rather than the activation corner.
func recordingOverlayFrame(size:NSSize,parent:NSRect,visible:NSRect)->NSRect {
 let available=visible.insetBy(dx:20,dy:20)
 let fitted=NSSize(width:min(size.width,max(1,available.width)),height:min(size.height,max(1,available.height)))
 return NSRect(x:min(max(parent.midX-fitted.width/2,available.minX),available.maxX-fitted.width),
               y:min(max(parent.midY-fitted.height/2,available.minY),available.maxY-fitted.height),width:fitted.width,height:fitted.height)
}

/// Arrival may move to the current Space; an established session never follows it.
enum OverlayPlacementPolicy {
 static var settled:NSWindow.CollectionBehavior {
  var behavior:NSWindow.CollectionBehavior = [.fullScreenAuxiliary,.ignoresCycle,.transient]
  if #available(macOS 13,*){behavior.insert(.canJoinAllApplications)}
  return behavior
 }
 static var arriving:NSWindow.CollectionBehavior {settled.union(.moveToActiveSpace)}
}
