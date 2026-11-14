// Disposable local fixture, no captured content or user preferences.
import AppKit
final class Host:NSObject,NSApplicationDelegate {
 var window:NSWindow!;var info=NSTextField(labelWithString:"");var changes=0
 var target=CommandLine.arguments.last!
 func applicationDidFinishLaunching(_ n:Notification){
  let menu=NSMenu();let item=NSMenuItem();item.submenu=NSMenu();item.submenu!.addItem(withTitle:"Quit QA Host",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");menu.addItem(item);NSApp.mainMenu=menu
  window=NSWindow(contentRect:NSRect(x:100,y:100,width:760,height:480),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false);window.title="LeviOsa Capture QA Host";window.collectionBehavior = [.fullScreenPrimary];window.isReleasedWhenClosed=false
  let view=window.contentView!
  let button=NSButton(title:"Open LeviOsa overlay",target:self,action:#selector(openCapture));button.bezelStyle = .rounded;button.frame=NSRect(x:240,y:220,width:280,height:40);view.addSubview(button)
  let full=NSButton(title:"Toggle Full Screen",target:self,action:#selector(fullscreen));full.bezelStyle = .rounded;full.frame=NSRect(x:240,y:160,width:280,height:40);view.addSubview(full)
  let input=NSTextField(frame:NSRect(x:240,y:300,width:280,height:30));input.placeholderString="Keyboard recovery check";view.addSubview(input)
  let cursor=NSButton(title:"Test cursor refresh",target:self,action:#selector(cursorRefresh));cursor.bezelStyle = .rounded;cursor.frame=NSRect(x:240,y:380,width:280,height:40);view.addSubview(cursor)
  let responder=NSButton(title:"Simulate responder drift",target:self,action:#selector(responderDrift));responder.bezelStyle = .rounded;responder.frame=NSRect(x:240,y:24,width:280,height:40);view.addSubview(responder)
  info.frame=NSRect(x:24,y:80,width:710,height:50);view.addSubview(info)
  NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(space),name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
  NotificationCenter.default.addObserver(self,selector:#selector(active),name:NSApplication.didBecomeActiveNotification,object:nil)
  update();window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
 }
 @objc func space(){changes += 1;update()}
 @objc func active(){update()}
 func update(){info.stringValue="Active: \(NSApp.isActive) · Space changes: \(changes) · Host on active Space: \(window?.isOnActiveSpace == true) · Full screen: \(window?.styleMask.contains(.fullScreen) == true)"}
 func capturePID()->String {for id in ["local.maxim.leviosa.review","com.maximkich.leviosa"]{if let app=NSRunningApplication.runningApplications(withBundleIdentifier:id).first{return String(app.processIdentifier)}};return target}
 @objc func openCapture(){NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil);DispatchQueue.main.asyncAfter(deadline:.now()+0.2){self.update();DistributedNotificationCenter.default().postNotificationName(Notification.Name("LeviOsaCaptureQAOpen"),object:self.capturePID(),userInfo:nil,deliverImmediately:true)}}
 @objc func fullscreen(){window.toggleFullScreen(nil)}
 @objc func cursorRefresh(){DistributedNotificationCenter.default().postNotificationName(Notification.Name("LeviOsaCaptureQACursorRefresh"),object:capturePID(),userInfo:nil,deliverImmediately:true)}
 @objc func responderDrift(){DistributedNotificationCenter.default().postNotificationName(Notification.Name("LeviOsaCaptureQAResponderChange"),object:capturePID(),userInfo:nil,deliverImmediately:true)}
}
let app=NSApplication.shared;let host=Host();app.delegate=host;app.setActivationPolicy(.regular);app.run()
