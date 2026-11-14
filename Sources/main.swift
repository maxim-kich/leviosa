// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Maxim Shevchenko-Tymchuk.
import AppKit
import ApplicationServices
import Carbon
import QuartzCore

func label(_ s:String,_ r:NSRect,_ size:CGFloat=13)->NSTextField {let l=NSTextField(wrappingLabelWithString:s);l.frame=r;l.font = .systemFont(ofSize:size,weight:size>=20 ? .semibold:.regular);return l}
func card(_ r:NSRect)->NSBox {let b=NSBox(frame:r);b.boxType = .custom;b.borderColor = .separatorColor;b.borderWidth=0.5;b.cornerRadius=12;b.fillColor = .controlBackgroundColor;b.contentViewMargins = .zero;return b}
// Center intrinsic text bounds on the native control alignment rect.
func alignLabel(_ label:NSTextField,with control:NSView){
 label.frame.size.height=ceil(label.intrinsicContentSize.height)
 label.frame.origin.y=control.alignmentRect(forFrame:control.frame).midY-label.frame.height/2
}
func alignRows(in view:NSView){
 if view is GestureSettingsView{return}
 for child in view.subviews where !(child is NSControl) { alignRows(in:child) }
 let controls=view.subviews.filter { $0 is NSButton || $0 is NSPopUpButton || $0 is NSSwitch }
 for control in controls {
  if let text=view.subviews.compactMap({$0 as? NSTextField}).filter({!$0.isEditable && abs($0.frame.midY-control.frame.midY)<16}).min(by:{abs($0.frame.midY-control.frame.midY)<abs($1.frame.midY-control.frame.midY)}) {alignLabel(text,with:control)}
 }
}
final class App:NSObject,NSApplicationDelegate,NSWindowDelegate,NSTableViewDataSource,NSTableViewDelegate {
 var updateButton=NSButton();var cancelUpdate=NSButton(title:"Cancel",target:nil,action:nil);var updaterMessage=NSTextField(wrappingLabelWithString:"")
 let drawing=DrawingController()
 var pad:Pad{drawing.pad}
 var navigation=NSTableView();var cornerRecognizer=CornerGesture()
 var backendAvailable=false;var backendGeneration:UInt64=0;var cornerDevice:UInt64?;var contactsByDevice=[UInt64:Int]()
 var settings:NSWindow!
 var body=NSView(frame:NSRect(x:220,y:0,width:640,height:640));var status=NSTextField(wrappingLabelWithString:"")
 let gestureSettings=GestureSettingsView(frame:NSRect(x:0,y:0,width:640,height:420))
 var editor=GestureDraft()
 var trainingSamples=[[Point]]()
 var storageLoadFailed=false
 var signalSources=[DispatchSourceSignal]();var qaObserver:NSObjectProtocol?;var qaCursorObserver:NSObjectProtocol?;var qaResponderObserver:NSObjectProtocol?
 var gestures=[Gesture]();var training=false;var selected=0;var bar:NSStatusItem!
 let shortcuts=ShortcutService()
 var shortcutRecorder:ShortcutRecorderView?
 var drawMenuItems=[NSMenuItem]()
 var shortcutFailure:ShortcutFailure?
 var updateRestartPaused=false
 var updateStoppedBackend=false
 let shortcutPermissionButton=NSButton(title:"Open System Settings…",target:nil,action:nil)
 let accessibilityStatus=NSTextField(labelWithString:"")
 var permissionTimer:Timer?
 var accessibilityGranted:Bool?
 let storage:URL = {
  if let directory=ProcessInfo.processInfo.environment["LEVIOSA_QA_DATA_DIRECTORY"] {return URL(fileURLWithPath:directory).appendingPathComponent("gestures.json")}
  return FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LeviOsa/gestures.json")
 }()
 func applicationDidFinishLaunching(_ n:Notification){
  let mainMenu=NSMenu();let appItem=NSMenuItem();let appMenu=NSMenu();appMenu.addItem(withTitle:"Settings…",action:#selector(showSettings),keyEquivalent:",").target=self;let draw=appMenu.addItem(withTitle:"Draw gesture…",action:#selector(drawGesture),keyEquivalent:"");draw.target=self;drawMenuItems.append(draw);appMenu.addItem(.separator());appMenu.addItem(withTitle:"Quit LeviOsa",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");appItem.submenu=appMenu;mainMenu.addItem(appItem);NSApp.mainMenu=mainMenu
  let editItem=NSMenuItem();let editMenu=NSMenu(title:"Edit")
  editMenu.addItem(withTitle:"Undo",action:Selector(("undo:")),keyEquivalent:"z")
  let redo=editMenu.addItem(withTitle:"Redo",action:Selector(("redo:")),keyEquivalent:"z");redo.keyEquivalentModifierMask=[.command,.shift]
  editMenu.addItem(.separator())
  editMenu.addItem(withTitle:"Cut",action:#selector(NSText.cut(_:)),keyEquivalent:"x")
  editMenu.addItem(withTitle:"Copy",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
  editMenu.addItem(withTitle:"Paste",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
  editMenu.addItem(withTitle:"Select All",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
  editItem.submenu=editMenu;mainMenu.addItem(editItem)

  do {gestures=try GestureStore.load(from:storage)}catch{storageLoadFailed=true;status.stringValue="Could not load saved gestures: \(error.localizedDescription)"}
  let menu=NSMenu();let drawStatus=menu.addItem(withTitle:"Draw gesture…",action:#selector(drawGesture),keyEquivalent:"");drawStatus.target=self;drawMenuItems.append(drawStatus);menu.addItem(withTitle:"Settings…",action:#selector(showSettings),keyEquivalent:"").target=self;menu.addItem(.separator());menu.addItem(withTitle:"Quit LeviOsa",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
  bar=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
  let menuIcon=Bundle.main.image(forResource:"MenuBarIcon")
  menuIcon?.isTemplate=true;menuIcon?.size=NSSize(width:18,height:18);menuIcon?.accessibilityDescription="LeviOsa"
  bar.button?.image=menuIcon;bar.menu=menu
  shortcuts.onTrigger={ [weak self] in
   guard let self,!self.updateRestartPaused,!ShortcutRecorderView.isRecording,NSApp.modalWindow == nil else{return}
   self.drawing.diagnostics.record("activation-shortcut",controller:self.drawing)
   self.drawGesture()
  }
  shortcutFailure=shortcuts.start();if let shortcutFailure{status.stringValue=shortcutFailure.message}
  updateShortcutMenus()
  UpdateChecker.shared.activity = { [weak self] in self?.updateActivity ?? UpdateActivity(selection:true) }
  UpdateChecker.shared.beforeRestart = { [weak self] valid,done in
   guard let self else{done(false);return};self.prepareUpdateRestart(stillAuthorized:valid,completion:done)
  }
  UpdateChecker.shared.abandonRestart = { [weak self] in self?.resumeAfterUpdateRestart() }
  NotificationCenter.default.addObserver(self,selector:#selector(updateStatus),name:UpdateChecker.changed,object:nil)
  NotificationCenter.default.addObserver(self,selector:#selector(showAbout),name:Notification.Name("LeviOsaShowAbout"),object:nil)
  UpdateChecker.shared.start()
  drawing.onSubmit={ [weak self] in self?.submit() }
  drawing.onError={ [weak self] text in self?.showGestureMessage(text) }
  gestureSettings.onTitle={ [weak self] text in guard let self else{return};self.editor.title=text;self.gestureSettings.updateSaveEnabled(self.editor.canSave) }
  gestureSettings.onRecord={ [weak self] in self?.train() }
  gestureSettings.onChooseApp={ [weak self] in self?.choose() }
  gestureSettings.onSave={ [weak self] in self?.saveGesture() }
  gestureSettings.onCancel={ [weak self] in self?.cancelGesture() }
  gestureSettings.onEdit={ [weak self] id in self?.editGesture(id) }
  gestureSettings.onDelete={ [weak self] id in self?.deleteGesture(id) }
  drawing.onSessionEnd={ [weak self] in
   guard let self else{return}
   if self.training{self.training=false;self.trainingSamples=[];self.gestureSettings.render(gestures:self.gestures,draft:self.editor)}
   if !UserDefaults.standard.bool(forKey:"cornerEnabled"){self.stopBackend()}
   self.cornerRecognizer.origin=nil;self.cornerRecognizer.blocked=self.contactsByDevice.values.contains{$0>0};self.cornerRecognizer.corner=UserDefaults.standard.integer(forKey:"corner");self.cornerDevice=nil
  }
  for number in [SIGTERM,SIGINT] {
   signal(number,SIG_IGN)
   let source=DispatchSource.makeSignalSource(signal:number,queue:.main)
   source.setEventHandler { NSApp.terminate(nil) };source.resume();signalSources.append(source)
  }
  if drawing.diagnostics.allowsQAControl {
   qaObserver=DistributedNotificationCenter.default().addObserver(forName:Notification.Name("LeviOsaCaptureQAOpen"),object:String(ProcessInfo.processInfo.processIdentifier),queue:.main){[weak self] _ in self?.drawGesture()}
   qaCursorObserver=DistributedNotificationCenter.default().addObserver(forName:Notification.Name("LeviOsaCaptureQACursorRefresh"),object:String(ProcessInfo.processInfo.processIdentifier),queue:.main){[weak self] _ in self?.drawing.exerciseCursorAppearanceForQA()}
   qaResponderObserver=DistributedNotificationCenter.default().addObserver(forName:Notification.Name("LeviOsaCaptureQAResponderChange"),object:String(ProcessInfo.processInfo.processIdentifier),queue:.main){[weak self] _ in self?.drawing.exerciseResponderChangeForQA()}
  }
  buildSettings();showSettings()
 }
 func button(_ title:String,_ r:NSRect,_ action:Selector,_ view:NSView){let b=NSButton(title:title,target:self,action:action);b.bezelStyle = .rounded;b.frame=r;view.addSubview(b)}
 func buildSettings(){
  settings=NSWindow(contentRect:NSRect(x:0,y:0,width:860,height:560),styleMask:[.titled,.closable,.miniaturizable,.fullSizeContentView],backing:.buffered,defer:false)
  settings.collectionBehavior = [.managed,.primary,.fullScreenPrimary];settings.title="LeviOsa";settings.titleVisibility = .hidden;settings.titlebarAppearsTransparent=true;settings.isReleasedWhenClosed=false
  settings.delegate=self
  let toolbar=NSToolbar(identifier:"SettingsHeader");settings.toolbar=toolbar;settings.toolbarStyle = .unified
  let root=settings.contentView!;let sideContent=NSView(frame:NSRect(x:0,y:0,width:204,height:544))
  if #available(macOS 26.0,*){let glass=NSGlassEffectView(frame:NSRect(x:8,y:8,width:204,height:544));glass.style = .regular;glass.cornerRadius=20;glass.contentView=sideContent;root.addSubview(glass)}else{let effect=NSVisualEffectView(frame:NSRect(x:8,y:8,width:204,height:544));effect.material = .sidebar;effect.addSubview(sideContent);root.addSubview(effect)}
  let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:204,height:500));scroll.drawsBackground=false
  let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("section"));column.width=204;navigation.addTableColumn(column);navigation.headerView=nil;navigation.rowHeight=34;navigation.intercellSpacing=NSSize(width:0,height:4);navigation.style = .sourceList;navigation.backgroundColor = .clear;navigation.dataSource=self;navigation.delegate=self;scroll.documentView=navigation;sideContent.addSubview(scroll)
  body.frame=NSRect(x:220,y:12,width:640,height:484);root.addSubview(body)
  root.addSubview(label("LeviOsa",NSRect(x:248,y:523,width:584,height:22)))
  navigation.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false);settings.center();refresh()
  if UserDefaults.standard.bool(forKey:"cornerEnabled"){startBackend()}
 }
 func numberOfRows(in tableView:NSTableView)->Int{3}
 func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView?{
  let cell=NSTableCellView()
  let icon=NSImageView();icon.translatesAutoresizingMaskIntoConstraints=false
  icon.image=NSImage(systemSymbolName:["gearshape","scribble","info.circle"][row],accessibilityDescription:nil);icon.contentTintColor = .secondaryLabelColor
  let text=NSTextField(labelWithString:["General","Gestures","About"][row]);text.font = .systemFont(ofSize:13);text.translatesAutoresizingMaskIntoConstraints=false
  cell.addSubview(icon);cell.addSubview(text);cell.textField=text;cell.imageView=icon
  NSLayoutConstraint.activate([
   icon.leadingAnchor.constraint(equalTo:cell.leadingAnchor,constant:8),
   icon.centerYAnchor.constraint(equalTo:cell.centerYAnchor),
   icon.widthAnchor.constraint(equalToConstant:18),icon.heightAnchor.constraint(equalToConstant:18),
   text.leadingAnchor.constraint(equalTo:icon.trailingAnchor,constant:8),
   text.centerYAnchor.constraint(equalTo:cell.centerYAnchor),
   text.trailingAnchor.constraint(lessThanOrEqualTo:cell.trailingAnchor,constant:-8)
  ])
  return cell
 }
 func tableViewSelectionDidChange(_ n:Notification){selected=max(0,navigation.selectedRow);refresh()}
 func refresh(){
  shortcutRecorder?.cancelRecording();shortcutRecorder=nil
  body.subviews.forEach{$0.removeFromSuperview()}
  body.addSubview(label(["General","Gestures","About"][selected],NSRect(x:28,y:438,width:560,height:34),24))
  if selected == 1 {
   body.addSubview(gestureSettings);gestureSettings.render(gestures:gestures,draft:editor)
  }else if selected == 0 {
   let shortcut=card(NSRect(x:24,y:298,width:592,height:112));body.addSubview(shortcut);let c=shortcut.contentView!
   c.addSubview(label("Keyboard shortcut",NSRect(x:16,y:69,width:450,height:22)))
   let enabled=NSSwitch(frame:NSRect(x:528,y:68,width:40,height:24));enabled.state=shortcuts.enabled ? .on:.off;enabled.target=self;enabled.action = #selector(shortcutEnabledChanged(_:));enabled.setAccessibilityLabel("Keyboard shortcut");c.addSubview(enabled)
   let text=label("Trigger Shortcut",NSRect(x:16,y:21,width:280,height:22));c.addSubview(text)
   let recorder=ShortcutRecorderView(current:{[weak self] in self?.shortcuts.shortcut ?? .defaultValue},onSave:{[weak self] value in
    guard let self else{return .unavailable(-1)}
    let error=self.shortcuts.change(to:value)
    if error == nil{self.shortcutFailure=nil;self.status.stringValue="";self.updateShortcutMenus();self.updateShortcutFeedback();self.drawing.diagnostics.record("shortcut-saved",controller:self.drawing)}
    return error
   },onRecording:{[weak self] active in
    guard let self else{return}
    if active{self.drawing.end(.settings);self.shortcuts.pause();self.shortcutFailure=nil;self.status.stringValue="";self.updateShortcutFeedback();self.drawing.diagnostics.record("shortcut-recording-start",controller:self.drawing)}
    else{if let error=self.shortcuts.resume(){self.showShortcutFailure(error)};self.drawing.diagnostics.record("shortcut-recording-end",controller:self.drawing)}
   },onFailure:{[weak self] error in self?.showShortcutFailure(error)})
   recorder.frame.origin=NSPoint(x:352,y:16);recorder.isEnabled=shortcuts.enabled;c.addSubview(recorder);shortcutRecorder=recorder
   text.frame.size.height=ceil(text.intrinsicContentSize.height);text.frame.origin.y=recorder.frame.minY+recorder.controlCenterY-text.frame.height/2
   let box=card(NSRect(x:24,y:170,width:592,height:112));body.addSubview(box)
   box.contentView?.addSubview(label("Trackpad corner swipe",NSRect(x:16,y:69,width:450,height:22)))
   let toggle=NSSwitch(frame:NSRect(x:528,y:68,width:40,height:24));toggle.state=UserDefaults.standard.bool(forKey:"cornerEnabled") ? .on:.off;toggle.target=self;toggle.action = #selector(cornerChanged(_:));box.contentView?.addSubview(toggle)
   box.contentView?.addSubview(label("One finger, diagonally inward",NSRect(x:16,y:26,width:350,height:22)))
   let corners=NSPopUpButton(frame:NSRect(x:386,y:22,width:190,height:28));corners.addItems(withTitles:["Top left","Top right","Bottom left","Bottom right"]);corners.selectItem(at:UserDefaults.standard.integer(forKey:"corner"));corners.target=self;corners.action = #selector(selectCorner(_:));box.contentView?.addSubview(corners)
   let permission=card(NSRect(x:24,y:90,width:592,height:64));body.addSubview(permission)
   let accessibilityLabel=label("Accessibility",NSRect(x:16,y:21,width:350,height:22))
   shortcutPermissionButton.frame=NSRect(x:400,y:17,width:176,height:30);shortcutPermissionButton.bezelStyle = .rounded
   shortcutPermissionButton.target=self;shortcutPermissionButton.action = #selector(openShortcutAccessibility)
   shortcutPermissionButton.setAccessibilityLabel("Manage Accessibility permission")
   accessibilityStatus.frame=NSRect(x:400,y:20,width:176,height:24);accessibilityStatus.font = .systemFont(ofSize:13);accessibilityStatus.alignment = .right
   accessibilityStatus.setAccessibilityLabel("Accessibility permission status")
   [accessibilityLabel,accessibilityStatus,shortcutPermissionButton].forEach{permission.contentView?.addSubview($0)}
   alignLabel(accessibilityLabel,with:shortcutPermissionButton);alignLabel(accessibilityStatus,with:shortcutPermissionButton)
   let permissionHint=label("Needed for drawing commands and Fn or modifier-only shortcuts.",NSRect(x:28,y:59,width:580,height:22),11)
   permissionHint.textColor = .secondaryLabelColor;body.addSubview(permissionHint)
  }else{
   let box=card(NSRect(x:24,y:70,width:592,height:340));body.addSubview(box);let c=box.contentView!
   let mark=NSImageView(frame:NSRect(x:246,y:210,width:100,height:100));mark.imageScaling = .scaleProportionallyUpOrDown;mark.image=NSImage(named:NSImage.applicationIconName);c.addSubview(mark)
   let title=label("LeviOsa",NSRect(x:16,y:170,width:560,height:32),24);title.alignment = .center;c.addSubview(title)
   let appVersion=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.0.1"
   let versionText="Version \(appVersion)"+(Bundle.main.bundleIdentifier == "com.maximkich.leviosa" ? "":" · Local review")
   let version=label(versionText,NSRect(x:16,y:136,width:560,height:22));version.alignment = .center;version.textColor = .secondaryLabelColor;c.addSubview(version)
   updateButton.target=self;updateButton.action = #selector(checkUpdate);updateButton.bezelStyle = .rounded;updateButton.frame=NSRect(x:202,y:91,width:188,height:32);c.addSubview(updateButton)
   cancelUpdate.target=self;cancelUpdate.action = #selector(cancelDownload);cancelUpdate.bezelStyle = .rounded;cancelUpdate.frame=NSRect(x:408,y:91,width:88,height:32);c.addSubview(cancelUpdate)
   updaterMessage.font = .systemFont(ofSize:11);updaterMessage.textColor = .secondaryLabelColor;updaterMessage.alignment = .center;updaterMessage.frame=NSRect(x:24,y:45,width:544,height:36);c.addSubview(updaterMessage)
   let credit=NSTextField(labelWithString:"");credit.isSelectable=true;credit.allowsEditingTextAttributes=true
   let attribution=NSMutableAttributedString(string:"Created by Maxim Kich",attributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.secondaryLabelColor])
   attribution.addAttribute(.link,value:URL(string:"https://maximkich.com")!,range:(attribution.string as NSString).range(of:"Maxim Kich"));credit.attributedStringValue=attribution;credit.frame=NSRect(x:28,y:30,width:300,height:ceil(credit.intrinsicContentSize.height));body.addSubview(credit)
   let links=NSStackView();links.orientation = .horizontal;links.spacing=12
   for title in ["Licenses"]{let b=NSButton(title:title,target:self,action:#selector(openAboutLink(_:)));b.isBordered=false;b.font = .systemFont(ofSize:11);b.contentTintColor = .secondaryLabelColor;links.addArrangedSubview(b)}
   let size=links.fittingSize;links.frame=NSRect(x:612-size.width,y:credit.frame.midY-size.height/2,width:size.width,height:size.height);body.addSubview(links)
   updateStatus()
  }
  alignRows(in:body)
  status.frame=NSRect(x:28,y:4,width:580,height:48);status.font = .systemFont(ofSize:11);status.textColor = .secondaryLabelColor;if selected == 0{body.addSubview(status)}
  updateShortcutFeedback()
  updatePermissionPolling()
 }
 @objc func updateStatus(){let u=UpdateChecker.shared;updateButton.title=u.primaryTitle;updateButton.isEnabled=u.primaryEnabled;cancelUpdate.isHidden = !u.canCancel;updaterMessage.stringValue=u.message}
 @objc func checkUpdate(){UpdateChecker.shared.openUpdate()}
 @objc func cancelDownload(){UpdateChecker.shared.cancel()}
 @objc func showAbout(){showSettings();navigation.selectRowIndexes(IndexSet(integer:2),byExtendingSelection:false);selected=2;refresh()}
 @objc func openAboutLink(_ sender:NSButton){NSWorkspace.shared.open(URL(string:"https://github.com/maxim-kich/leviosa/blob/main/ACKNOWLEDGEMENTS.md")!)}
 func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply{UpdateChecker.shared.permitsTermination() ? .terminateNow:.terminateCancel}
 func updateShortcutMenus(){for item in drawMenuItems{item.title="Draw gesture…"+(shortcuts.enabled ? "  "+shortcuts.shortcut.title:"")}}
 func showShortcutFailure(_ error:ShortcutFailure){shortcutFailure=error;status.stringValue=error.message;updateShortcutFeedback();drawing.diagnostics.record("shortcut-rejected",controller:drawing)}
 func updateShortcutFeedback(){
  status.frame.size.width=580
 }
 func refreshAccessibility(){
  let granted=AXIsProcessTrusted()
  accessibilityStatus.stringValue=granted ? "Allowed":"Not allowed";accessibilityStatus.textColor = .systemGreen
  accessibilityStatus.isHidden = !granted;shortcutPermissionButton.isHidden=granted
  if granted,accessibilityGranted != true,shortcutFailure == .accessibility,!ShortcutRecorderView.isRecording,!updateRestartPaused,!drawing.open {
   shortcutFailure=shortcuts.start();status.stringValue=shortcutFailure?.message ?? ""
  }
  accessibilityGranted=granted
 }
 func updatePermissionPolling(){
  permissionTimer?.invalidate();permissionTimer=nil
  guard selected == 0,settings?.isVisible == true,settings?.isKeyWindow == true,NSApp.isActive,!drawing.open else{return}
  refreshAccessibility()
  permissionTimer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in
   guard let self else{return}
   guard self.selected == 0,self.settings.isVisible,self.settings.isKeyWindow,NSApp.isActive,!self.drawing.open else{self.permissionTimer?.invalidate();self.permissionTimer=nil;return}
   self.refreshAccessibility()
  }
 }
 func applicationDidBecomeActive(_ notification:Notification){updatePermissionPolling()}
 func applicationDidResignActive(_ notification:Notification){permissionTimer?.invalidate();permissionTimer=nil}
 func windowDidBecomeKey(_ notification:Notification){updatePermissionPolling()}
 func windowDidResignKey(_ notification:Notification){permissionTimer?.invalidate();permissionTimer=nil}
 func windowWillClose(_ notification:Notification){permissionTimer?.invalidate();permissionTimer=nil}
 @objc func shortcutEnabledChanged(_ sender:NSSwitch){
  if let error=shortcuts.setEnabled(sender.state == .on){sender.state=shortcuts.enabled ? .on:.off;showShortcutFailure(error);return}
  shortcutFailure=nil;status.stringValue="";shortcutRecorder?.isEnabled=shortcuts.enabled;updateShortcutMenus();updateShortcutFeedback()
 }
 @objc func openShortcutAccessibility(){shortcutRecorder?.cancelRecording();NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)}
 @objc func selectCorner(_ sender:NSPopUpButton){UserDefaults.standard.set(sender.indexOfSelectedItem,forKey:"corner");cornerRecognizer=CornerGesture();cornerRecognizer.corner=sender.indexOfSelectedItem}
 @objc func cornerChanged(_ sender:NSSwitch){
  let enabled=sender.state == .on;UserDefaults.standard.set(enabled,forKey:"cornerEnabled")
  if enabled{startBackend()}else if !drawing.open{stopBackend()};refresh()
 }
 func stopBackend(){backendGeneration &+= 1;LVStop();backendAvailable=false;contactsByDevice.removeAll();cornerDevice=nil}
 var updateActivity:UpdateActivity {
  UpdateActivity(selection:drawing.open,shortcutRecording:ShortcutRecorderView.isRecording,unsavedGesture:!editor.isEmpty)
 }
 func prepareUpdateRestart(stillAuthorized:@escaping ()->Bool,completion:@escaping (Bool)->Void){
  guard stillAuthorized(),updateActivity.restartBlock == nil else{completion(false);return}
  if !updateRestartPaused {
   updateStoppedBackend=backendAvailable;updateRestartPaused=true
   shortcuts.pause();stopBackend();drawing.end(.terminate)
  }
  DispatchQueue.main.async { [weak self] in
   guard let self else{completion(false);return}
   guard stillAuthorized() else{self.resumeAfterUpdateRestart();completion(false);return}
   completion(self.updateRestartPaused && !self.backendAvailable && !self.drawing.cursor.ownsResources && !self.drawing.keyboard.isMonitoring && self.updateActivity.restartBlock == nil)
  }
 }
 func resumeAfterUpdateRestart(){
  guard updateRestartPaused else{return}
  updateRestartPaused=false
  let restartBackend=updateStoppedBackend;updateStoppedBackend=false
  if restartBackend && UserDefaults.standard.bool(forKey:"cornerEnabled"){startBackend()}
  if let failure=shortcuts.resume(){showShortcutFailure(failure)}
 }
 func startBackend(){
  guard !updateRestartPaused,!backendAvailable else{return}
  backendGeneration &+= 1
  cornerRecognizer=CornerGesture();cornerRecognizer.corner=UserDefaults.standard.integer(forKey:"corner")
  backendAvailable=LVStart({ device,count,id,x,y,time,generation in
   let receivedAt=ProcessInfo.processInfo.systemUptime
   DispatchQueue.main.async {
   guard let app=NSApp.delegate as? App,app.backendGeneration==generation else{return}
   if let current=app.cornerDevice,current != device,!app.drawing.open{return}
   app.contactsByDevice[device]=Int(count)
   if app.drawing.open{app.drawing.rawTouch(device:device,count:Int(count),id:Int(id),x:x,y:y,receivedAt:receivedAt);return}
   guard UserDefaults.standard.bool(forKey:"cornerEnabled"),NSApp.modalWindow==nil,!ShortcutRecorderView.isRecording else{return}
   if count>0,app.cornerDevice==nil{app.cornerDevice=device}
   app.cornerRecognizer.resetOnLift(count:Int(count))
   let trigger=app.cornerRecognizer.feed(count:Int(count),id:Int(id),x:x,y:y,time:time)
   if count==0{app.cornerDevice=nil}
   if trigger{app.training=false;app.openPad()}
  }},backendGeneration)
  if !backendAvailable{status.stringValue="Trackpad input unavailable. Re-enable corner swipe or restart LeviOsa to retry."}
 }
 func showGestureMessage(_ message:String){status.stringValue=message;gestureSettings.setMessage(message)}
 @objc func choose(){
  let picker=NSOpenPanel();picker.canChooseDirectories=false;picker.allowedContentTypes=[.applicationBundle]
  picker.directoryURL=URL(fileURLWithPath:"/Applications")
  if picker.runModal() == .OK,let url=picker.url {editor.appPath=url.path;gestureSettings.render(gestures:gestures,draft:editor)}
 }
 func editGesture(_ id:UUID){
  guard let gesture=gestures.first(where:{$0.id == id}) else{return}
  editor.edit(gesture);status.stringValue="";gestureSettings.render(gestures:gestures,draft:editor,focusTitle:true)
 }
 func cancelGesture(){editor.cancel();status.stringValue="";gestureSettings.render(gestures:gestures,draft:editor)}
 @discardableResult func persist(_ next:[Gesture])->Bool{
  guard !storageLoadFailed else{showGestureMessage("The saved library could not be loaded. Restore it before saving changes.");return false}
  do{try GestureStore.save(next,to:storage);gestures=next;return true}
  catch{showGestureMessage("Could not save changes. \(error.localizedDescription)");return false}
 }
 func deleteGesture(_ id:UUID){
  guard gestures.contains(where:{$0.id == id}),persist(gestures.filter{$0.id != id}) else{return}
  if editor.editingID == id{editor.cancel()}
  gestureSettings.render(gestures:gestures,draft:editor)
 }
 @objc func saveGesture(){
  guard editor.canSave else{return}
  do{
   let next=try editor.applying(to:gestures)
   guard persist(next) else{return}
   editor.cancel();gestureSettings.render(gestures:gestures,draft:editor)
  }catch{showGestureMessage("This gesture could not be saved. Cancel and try again.")}
 }
 @objc func train(){guard !updateRestartPaused else{return};trainingSamples=[];training=true;openPad()}
 @objc func drawGesture(){guard !updateRestartPaused else{return};if drawing.open{drawing.end(.shortcut);return};training=false;openPad()}
 func openPad(){
  guard !updateRestartPaused,!drawing.open else{return}
  shortcutRecorder?.cancelRecording()
  guard AXIsProcessTrusted() else {
   training=false;selected=0;navigation.selectRowIndexes(IndexSet(integer:0),byExtendingSelection:false);refresh();showSettings()
   showGestureMessage("Allow LeviOsa in Accessibility, then try drawing again.");return
  }
  if !backendAvailable{startBackend()}
  guard backendAvailable else{training=false;showGestureMessage("Trackpad input unavailable. Re-enable corner swipe or restart LeviOsa to retry.");showSettings();return}
  drawing.present(corner:UserDefaults.standard.integer(forKey:"corner"),title:training ? "Example \(trainingSamples.count+1) of 3":"Draw your symbol",contactsDown:contactsByDevice.values.contains{$0>0},device:cornerDevice ?? contactsByDevice.keys.sorted().first(where:{contactsByDevice[$0,default:0]>0}),above:training ? settings:nil)
 }
 func updateMessage(){drawing.updateTitle(training ? "Example \(trainingSamples.count+1) of 3":"Draw your symbol")}
 func rejectDrawing(_ text:String){drawing.reject(text)}
 @objc func clear(){pad.clear();updateMessage()}
 @objc func cancelPad(){drawing.end(.escape)}
 @objc func submit(){guard !pad.mouse,!pad.touching else{drawing.waitForLift();return};guard Recognizer.normalize(pad.points).count == 64 else{rejectDrawing("Too short · draw again");return}
  if training {
   if let first=trainingSamples.first,Recognizer.error(first,pad.points)>0.20{rejectDrawing("Example differs · draw again");return}
   trainingSamples.append(pad.points);pad.clear()
   if trainingSamples.count == 3 {editor.samples=trainingSamples;trainingSamples=[];training=false;drawing.end(.submitted);gestureSettings.render(gestures:gestures,draft:editor);showSettings()}else{updateMessage()}
  }else{
   guard let (i,_)=Recognizer.match(pad.points,gestures) else{rejectDrawing("No match · draw again");return};let g=gestures[i];drawing.end(.submitted);NSWorkspace.shared.openApplication(at:URL(fileURLWithPath:g.app),configuration:NSWorkspace.OpenConfiguration()){_,error in DispatchQueue.main.async{self.status.stringValue=error.map{"Launch failed: \($0.localizedDescription)"} ?? "Opened \(g.displayTitle)"}}
  }
 }
 @objc func showSettings(){drawing.end(.settings);NSApp.activate(ignoringOtherApps:true);settings.makeKeyAndOrderFront(nil)}
 func applicationWillTerminate(_ n:Notification){permissionTimer?.invalidate();permissionTimer=nil;shortcutRecorder?.cancelRecording();shortcuts.stop();drawing.end(.terminate);stopBackend()}
}
// Prevent a second copy from registering input or acquiring the cursor.
let instanceDirectory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LeviOsa")
do {try FileManager.default.createDirectory(at:instanceDirectory,withIntermediateDirectories:true)} catch {fputs("Could not initialize LeviOsa instance directory.\n",stderr);exit(1)}
let instanceLock=instanceDirectory.appendingPathComponent("instance.lock")
guard instanceLock.path.withCString({LVAcquireInstance($0)}) else {
 if let existing=NSRunningApplication.runningApplications(withBundleIdentifier:Bundle.main.bundleIdentifier ?? "local.maxim.leviosa.review").first(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}) {existing.activate(options:[])}
 exit(0)
}
let app=NSApplication.shared
if Bundle.main.bundleIdentifier == "com.maximkich.leviosa" {
 PreferencesUpgrade.importReview(UserDefaults.standard.persistentDomain(forName:"local.maxim.leviosa.review"),into:.standard)
}
let delegate=App();app.delegate=delegate;app.setActivationPolicy(.accessory)
app.run()
