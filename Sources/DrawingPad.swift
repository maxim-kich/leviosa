// SPDX-License-Identifier: MIT
import AppKit
final class Pad:NSView {
 var points=[Point]();var stroke=0;var touching=false;var mouse=false
 var capturing=false
 var deviceChanged:((NSSize)->Void)?;var submitAction:(()->Void)?;var clearAction:(()->Void)?;var closeAction:(()->Void)?
 var drawingChanged:((Bool)->Void)?
 var rawAwaitLift=true;var rawID:Int?;var rawDevice:UInt64?
 var deviceSize=NSSize.zero
 var sampleCountChanged:((Int)->Void)?
 override func keyDown(with event:NSEvent){
  guard let command=DrawingCommand.decode(keyCode:event.keyCode,characters:event.charactersIgnoringModifiers,modified:!event.modifierFlags.intersection([.command,.control,.option]).isEmpty) else {super.keyDown(with:event);return}
  switch command {case .submit:submitAction?();case .clear:clearAction?();case .cancel:closeAction?()}
 }
 override func cancelOperation(_ sender:Any?){closeAction?()}
 override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
 override var acceptsFirstResponder:Bool {true}
 override init(frame:NSRect){super.init(frame:frame);allowedTouchTypes = [.indirect];wantsRestingTouches=false;wantsLayer=true;layer?.cornerRadius=12;layer?.backgroundColor=NSColor.clear.cgColor}
 required init?(coder:NSCoder){fatalError()}
 func clear(){rawID=nil;if !capturing{rawDevice=nil};rawAwaitLift=touching;points=[];stroke=0;touching=false;mouse=false;drawingChanged?(false);needsDisplay=true}
 func add(_ p:NSPoint){if points.isEmpty{drawingChanged?(true)};points.append(Point(x:p.x,y:p.y,stroke:stroke));sampleCountChanged?(points.count);needsDisplay=true}
 override func mouseDown(with e:NSEvent){guard capturing,!touching else{return};mouse=true;stroke += 1;add(convert(e.locationInWindow,from:nil))}
 override func mouseDragged(with e:NSEvent){if mouse {if capturing,let last=points.last{add(NSPoint(x:max(0,min(bounds.width,last.x+e.deltaX)),y:max(0,min(bounds.height,last.y-e.deltaY))))}else{add(convert(e.locationInWindow,from:nil))}}}
 override func mouseUp(with e:NSEvent){mouse=false}
 // Public touches supply device size only. Raw input is the sole trackpad stroke source.
 override func touchesBegan(with e:NSEvent){if let t=e.touches(matching:.touching,in:self).first,t.deviceSize != deviceSize{deviceSize=t.deviceSize;deviceChanged?(deviceSize)}}
 override func touchesMoved(with e:NSEvent){}
 override func touchesEnded(with e:NSEvent){}
 override func touchesCancelled(with e:NSEvent){}
 func rawTouch(device:UInt64,count:Int,id:Int,x:Double,y:Double){
  guard capturing,!mouse else{return}
  // Once a session selects a trackpad, frames from another device cannot lift or join it.
  if let rawDevice,rawDevice != device{return}
  if rawDevice == nil,count>0{rawDevice=device}
  if count==0{rawAwaitLift=false;rawID=nil;touching=false;return}
  guard count==1,!rawAwaitLift,x.isFinite,y.isFinite,(0...1).contains(x),(0...1).contains(y) else{rawAwaitLift=true;rawID=nil;touching=count>0;return}
  if rawID != id {guard rawID==nil else{rawAwaitLift=true;touching=false;return};rawID=id;stroke += 1}
  touching=true;add(NSPoint(x:x*bounds.width,y:y*bounds.height))
 }
 override func scrollWheel(with e:NSEvent){}
 override func draw(_ dirty:NSRect){super.draw(dirty);NSColor.controlAccentColor.setStroke();let path=NSBezierPath();path.lineWidth=3;path.lineCapStyle = .round;for (i,p) in points.enumerated(){let q=NSPoint(x:p.x,y:p.y);if i == 0 || points[i-1].stroke != p.stroke{path.move(to:q)}else{path.line(to:q)}};path.stroke()}
}
