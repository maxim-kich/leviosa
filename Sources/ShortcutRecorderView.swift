// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Maxim Shevchenko-Tymchuk.
import AppKit

final class ShortcutRecorderView: NSView {
    static private(set) var isRecording = false
    private let button=NSButton(title:"",target:nil,action:nil)
    private let reset=NSButton()
    private var monitor: Any?
    private var deactivation: NSObjectProtocol?
    private var recording=ShortcutRecordingState()
    private let current: () -> ActivationShortcut
    private let onSave: (ActivationShortcut) -> ShortcutFailure?
    private let onRecording: (Bool) -> Void
    private let onFailure: (ShortcutFailure) -> Void
    init(current: @escaping () -> ActivationShortcut, onSave: @escaping (ActivationShortcut) -> ShortcutFailure?,
         onRecording: @escaping (Bool) -> Void, onFailure: @escaping (ShortcutFailure) -> Void) {
        self.current=current;self.onSave=onSave;self.onRecording=onRecording;self.onFailure=onFailure
        super.init(frame:NSRect(x:0,y:0,width:224,height:32))
        button.frame=NSRect(x:0,y:0,width:184,height:32);button.bezelStyle = .rounded
        button.target=self;button.action = #selector(startRecording)
        button.setAccessibilityLabel("Trigger Shortcut")
        button.toolTip="Click, then press a shortcut, including Fn or a modifier combination. Escape cancels."
        addSubview(button)
        reset.frame=NSRect(x:192,y:2,width:28,height:28);reset.bezelStyle = .inline
        reset.image=NSImage(systemSymbolName:"arrow.counterclockwise",accessibilityDescription:"Reset shortcut")
        reset.target=self;reset.action = #selector(resetShortcut);reset.toolTip="Reset to Control + Option + G"
        addSubview(reset)
        reset.frame.origin.y += controlCenterY-reset.alignmentRect(forFrame:reset.frame).midY
        refresh()
    }
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    var controlCenterY: CGFloat {button.alignmentRect(forFrame:button.frame).midY}
    var isEnabled: Bool {
        get {button.isEnabled}
        set {if !newValue{cancelRecording()};button.isEnabled=newValue;reset.isEnabled=newValue}
    }
    func refresh() {
        button.title=current().title
        reset.isHidden=current() == .defaultValue
        button.frame.origin.x=reset.isHidden ? bounds.width-button.frame.width:0
    }
    @objc private func startRecording() {
        if monitor != nil {cancelRecording();return}
        Self.isRecording=true;onRecording(true);recording=ShortcutRecordingState()
        button.title="Press shortcut…"
        deactivation=NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:window,queue:.main){[weak self] _ in self?.cancelRecording()}
        monitor=NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.flagsChanged,.leftMouseDown,.rightMouseDown]){[weak self] event in
            guard let self else{return event}
            if event.type == .leftMouseDown || event.type == .rightMouseDown {self.cancelRecording();return event}
            if event.type == .keyDown,event.isARepeat{return nil}
            let flags=UInt64(event.modifierFlags.rawValue)
            let result:ShortcutRecordingState.Result
            if event.type == .flagsChanged {
                result=self.recording.flagsChanged(flags)
                let masked=flags & UInt64(ActivationShortcut.modifierMask.rawValue)
                if masked != 0 {self.button.title=ActivationShortcut(modifiers:masked,keyCode:nil,keyLabel:"").title}
            }else{
                let names:[UInt16:String]=[49:"Space",36:"↩",76:"⌤",48:"⇥",51:"⌫",117:"⌦",123:"←",124:"→",125:"↓",126:"↑",115:"↖",119:"↘",116:"⇞",121:"⇟"]
                let label=names[event.keyCode] ?? event.specialKey.flatMap{key in (NSEvent.SpecialKey.f1.rawValue...NSEvent.SpecialKey.f20.rawValue).contains(key.rawValue) ? "F\(key.rawValue-NSEvent.SpecialKey.f1.rawValue+1)":nil} ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
                result=self.recording.keyDown(code:event.keyCode,flags:flags,label:label)
            }
            switch result {
            case .waiting:break
            case .cancel:self.cancelRecording()
            case .invalid:self.onFailure(.invalid);NSSound.beep()
            case .save(let shortcut):self.save(shortcut)
            }
            return nil
        }
        if monitor == nil {cancelRecording();onFailure(.unavailable(-1))}
    }
    private func save(_ shortcut:ActivationShortcut) {
        if let error=onSave(shortcut) {
            button.title="Try another shortcut…";onFailure(error);NSSound.beep();return
        }
        cancelRecording()
    }
    func cancelRecording() {
        let wasRecording=monitor != nil || Self.isRecording
        if let monitor{NSEvent.removeMonitor(monitor)}
        if let deactivation{NotificationCenter.default.removeObserver(deactivation)}
        monitor=nil;deactivation=nil
        if wasRecording{Self.isRecording=false;onRecording(false)}
        refresh()
    }
    @objc private func resetShortcut(){save(.defaultValue)}
    override func viewWillMove(toWindow newWindow:NSWindow?) {
        if newWindow == nil{cancelRecording()}
        super.viewWillMove(toWindow:newWindow)
    }
    deinit {
        if let monitor{NSEvent.removeMonitor(monitor)}
        if let deactivation{NotificationCenter.default.removeObserver(deactivation)}
    }
}
