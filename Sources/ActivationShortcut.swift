// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Maxim Shevchenko-Tymchuk.
import AppKit
import Carbon
import ApplicationServices

struct ActivationShortcut: Codable, Equatable {
    let modifiers: UInt64
    let keyCode: UInt16?
    let keyLabel: String
    static let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]
    static let primaryMask: NSEvent.ModifierFlags = [.control, .option, .command, .function]
    static let defaultValue = Self(modifiers: UInt64(NSEvent.ModifierFlags([.control, .option]).rawValue), keyCode: 5, keyLabel: "G")
    static let storageKey = "activationShortcut"
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data=defaults.data(forKey:storageKey),
              let value=try? JSONDecoder().decode(Self.self,from:data),value.isValid else{return .defaultValue}
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self),forKey:Self.storageKey)
    }
    var isValid: Bool {
        guard modifiers & UInt64(Self.primaryMask.rawValue) != 0,
              modifiers & ~UInt64(Self.modifierMask.rawValue) == 0 else{return false}
        guard let keyCode else{return keyLabel.isEmpty}
        return keyCode < 128 && ![53,54,55,56,57,58,59,60,61,62,63].contains(keyCode)
            && !keyLabel.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && keyLabel.count <= 32
    }
    var title: String {
        let flags=NSEvent.ModifierFlags(rawValue:UInt(modifiers))
        return [(NSEvent.ModifierFlags.function,"fn"),(.control,"⌃"),(.option,"⌥"),(.shift,"⇧"),(.command,"⌘")]
            .filter{flags.contains($0.0)}.map(\.1).joined()+keyLabel
    }
    var needsObservation: Bool { keyCode == nil || modifiers & UInt64(NSEvent.ModifierFlags.function.rawValue) != 0 }
    var carbonModifiers: UInt32 {
        let flags=NSEvent.ModifierFlags(rawValue:UInt(modifiers))
        return (flags.contains(.control) ? UInt32(controlKey):0) |
            (flags.contains(.option) ? UInt32(optionKey):0) |
            (flags.contains(.shift) ? UInt32(shiftKey):0) |
            (flags.contains(.command) ? UInt32(cmdKey):0)
    }
}

enum ShortcutFailure: Error, Equatable {
    case invalid, accessibility, unavailable(OSStatus)
    var message: String {
        switch self {
        case .invalid: return "Choose Command, Control, Option or Fn, with an optional key. Escape cancels."
        case .accessibility: return "Fn and modifier-only shortcuts need Accessibility access. Choose a shortcut with a key, or allow LeviOsa in System Settings."
        case .unavailable: return "That shortcut is unavailable or already in use. Choose another; your previous shortcut is unchanged."
        }
    }
}

/// A recorder rejects plain typing and does not mistake a rejected key's release for a modifier-only shortcut.
struct ShortcutRecordingState {
    enum Result { case waiting, cancel, invalid, save(ActivationShortcut) }
    private var peak: UInt64 = 0
    private var currentFlags: UInt64 = 0
    private var ignoreUntilLift = false
    mutating func flagsChanged(_ flags: UInt64) -> Result {
        currentFlags=flags & UInt64(ActivationShortcut.modifierMask.rawValue)
        if ignoreUntilLift { if currentFlags == 0 {ignoreUntilLift=false};return .waiting }
        if currentFlags == 0,peak != 0 {
            let value=ActivationShortcut(modifiers:peak,keyCode:nil,keyLabel:"");peak=0
            return value.isValid ? .save(value):.invalid
        }
        if currentFlags.nonzeroBitCount >= peak.nonzeroBitCount {peak=currentFlags}
        return .waiting
    }
    mutating func keyDown(code: UInt16, flags: UInt64, label: String) -> Result {
        if code == 53{return .cancel}
        var modifiers=flags & UInt64(ActivationShortcut.modifierMask.rawValue)
        // AppKit adds .function to arrows/function keys even without a physical Fn press.
        if currentFlags & UInt64(NSEvent.ModifierFlags.function.rawValue) == 0 {
            modifiers &= ~UInt64(NSEvent.ModifierFlags.function.rawValue)
        }
        let value=ActivationShortcut(modifiers:modifiers,keyCode:code,keyLabel:label)
        peak=0;ignoreUntilLift=true
        return value.isValid ? .save(value):.invalid
    }
}

protocol ShortcutRegistration: AnyObject { func invalidate() }

/// Register a replacement before retiring the previous binding. Pausing releases the global
/// registration so the recorder can receive even the currently configured shortcut.
final class ShortcutService {
    typealias Factory = (ActivationShortcut, UInt32, @escaping () -> Void) throws -> ShortcutRegistration
    private let defaults: UserDefaults
    private let factory: Factory
    private var registration: ShortcutRegistration?
    private var nextID: UInt32 = 0
    private var activeID: UInt32?
    private(set) var shortcut: ActivationShortcut
    private(set) var enabled: Bool
    private(set) var paused = false
    var onTrigger: (() -> Void)?
    init(defaults: UserDefaults = .standard, factory: Factory? = nil) {
        self.defaults=defaults;self.factory=factory ?? NativeShortcutRegistration.make
        shortcut=ActivationShortcut.load(from:defaults);enabled = !defaults.bool(forKey:"shortcutDisabled")
    }
    @discardableResult func start() -> ShortcutFailure? {
        guard enabled,!paused,registration == nil else{return nil}
        do {let (value,id)=try make(shortcut);registration=value;activeID=id;return nil}
        catch {return (error as? ShortcutFailure) ?? .unavailable(-1)}
    }
    private func make(_ candidate: ActivationShortcut) throws -> (ShortcutRegistration,UInt32) {
        nextID &+= 1;let id=nextID
        let value=try factory(candidate,id) { [weak self] in
            guard let self,self.enabled,!self.paused,self.activeID == id else{return}
            self.onTrigger?()
        }
        return (value,id)
    }
    @discardableResult func change(to candidate: ActivationShortcut) -> ShortcutFailure? {
        guard candidate.isValid else{return .invalid}
        if candidate == shortcut,registration != nil{return nil}
        var replacement: ShortcutRegistration?;var id: UInt32?
        if enabled {
            do {let result=try make(candidate);replacement=result.0;id=result.1}
            catch {return (error as? ShortcutFailure) ?? .unavailable(-1)}
        }
        let old=registration;registration=replacement;activeID=id;old?.invalidate()
        shortcut=candidate;candidate.save(to:defaults)
        return nil
    }
    @discardableResult func setEnabled(_ value: Bool) -> ShortcutFailure? {
        if value == enabled {return start()}
        if value {
            do {let (new,id)=try make(shortcut);registration=new;activeID=id}
            catch {return (error as? ShortcutFailure) ?? .unavailable(-1)}
        } else {stop()}
        enabled=value;defaults.set(!value,forKey:"shortcutDisabled");return nil
    }
    func pause() {paused=true;stop()}
    @discardableResult func resume() -> ShortcutFailure? {paused=false;return start()}
    func stop() {activeID=nil;let old=registration;registration=nil;old?.invalidate()}
    deinit {stop()}
}

private enum NativeShortcutRegistration {
    static func make(_ shortcut: ActivationShortcut, id: UInt32, fire: @escaping () -> Void) throws -> ShortcutRegistration {
        guard shortcut.isValid else{throw ShortcutFailure.invalid}
        if shortcut.keyCode == nil {return try ObservedShortcutRegistration(shortcut:shortcut,fire:fire)}
        if shortcut.needsObservation {return try FnShortcutRegistration(shortcut:shortcut,fire:fire)}
        return try CarbonShortcutRegistration(shortcut:shortcut,id:id,fire:fire)
    }
}

private final class CarbonShortcutRegistration: ShortcutRegistration {
    private static let signature: OSType = 0x4C565341
    private let id: UInt32
    private let fire: () -> Void
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var down = false
    init(shortcut: ActivationShortcut, id: UInt32, fire: @escaping () -> Void) throws {
        self.id=id;self.fire=fire
        var types=[EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed)),
                   EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyReleased))]
        let result=InstallEventHandler(GetApplicationEventTarget(),{_,event,context in
            guard let event,let context else{return OSStatus(eventNotHandledErr)}
            let owner=Unmanaged<CarbonShortcutRegistration>.fromOpaque(context).takeUnretainedValue()
            var value=EventHotKeyID()
            guard GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&value) == noErr,
                  value.signature == CarbonShortcutRegistration.signature,value.id == owner.id else{return OSStatus(eventNotHandledErr)}
            if GetEventKind(event) == UInt32(kEventHotKeyReleased) {owner.down=false}
            else if !owner.down {owner.down=true;DispatchQueue.main.async{[weak owner] in owner?.fire()}}
            return noErr
        },2,&types,Unmanaged.passUnretained(self).toOpaque(),&handler)
        guard result == noErr else{throw ShortcutFailure.unavailable(result)}
        let registered=RegisterEventHotKey(UInt32(shortcut.keyCode!),shortcut.carbonModifiers,EventHotKeyID(signature:Self.signature,id:id),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&hotkey)
        guard registered == noErr else{invalidate();throw ShortcutFailure.unavailable(registered)}
    }
    func invalidate() {
        if let hotkey {UnregisterEventHotKey(hotkey);self.hotkey=nil}
        if let handler {RemoveEventHandler(handler);self.handler=nil}
        down=false
    }
    deinit {invalidate()}
}

/// Modifier-only activation waits for release and cancels when the chord was used to type
/// another command. These optional observers always pass the original events through.
struct ObservedShortcutState {
    let shortcut: ActivationShortcut
    var awaitNeutral: Bool
    private var armed = false
    private var cancelled = false
    private var keyHeld = false
    private var physicalFlags: UInt64 = 0
    init(shortcut: ActivationShortcut, awaitNeutral: Bool = false) {self.shortcut=shortcut;self.awaitNeutral=awaitNeutral}
    mutating func handle(type: NSEvent.EventType, flags raw: UInt64, keyCode: UInt16, repeatKey: Bool = false) -> Bool {
        var flags=raw & UInt64(ActivationShortcut.modifierMask.rawValue)
        if type == .flagsChanged {physicalFlags=flags}
        else if physicalFlags & UInt64(NSEvent.ModifierFlags.function.rawValue) == 0 {
            flags &= ~UInt64(NSEvent.ModifierFlags.function.rawValue)
        }
        if awaitNeutral {if flags == 0{awaitNeutral=false};return false}
        if let code=shortcut.keyCode {
            if type == .keyUp,keyCode == code {keyHeld=false}
            if type == .keyDown,keyCode == code,!repeatKey,!keyHeld,flags == shortcut.modifiers {
                keyHeld=true;return true
            }
            return false
        }
        if type == .keyDown,armed {cancelled=true}
        guard type == .flagsChanged else{return false}
        if flags == 0 {
            let trigger=armed && !cancelled
            armed=false;cancelled=false;return trigger
        }
        if flags == shortcut.modifiers {armed=true}
        if flags & ~shortcut.modifiers != 0 {cancelled=true}
        return false
    }
}

private final class ObservedShortcutRegistration: ShortcutRegistration {
    private var global: Any?
    private var local: Any?
    private var state: ObservedShortcutState
    private let fire: () -> Void
    init(shortcut: ActivationShortcut, fire: @escaping () -> Void) throws {
        self.fire=fire
        state=ObservedShortcutState(shortcut:shortcut,awaitNeutral:!NSEvent.modifierFlags.intersection(ActivationShortcut.modifierMask).isEmpty)
        guard AXIsProcessTrusted() else{throw ShortcutFailure.accessibility}
        let mask:NSEvent.EventTypeMask=[.flagsChanged,.keyDown,.keyUp]
        global=NSEvent.addGlobalMonitorForEvents(matching:mask){[weak self] event in self?.handle(event)}
        local=NSEvent.addLocalMonitorForEvents(matching:mask){[weak self] event in self?.handle(event);return event}
        guard global != nil,local != nil else{invalidate();throw ShortcutFailure.unavailable(-1)}
    }
    private func handle(_ event:NSEvent) {
        guard state.handle(type:event.type,flags:UInt64(event.modifierFlags.rawValue),keyCode:event.keyCode,repeatKey:event.isARepeat) else{return}
        DispatchQueue.main.async{[weak self] in self?.fire()}
    }
    func invalidate() {
        if let global {NSEvent.removeMonitor(global);self.global=nil}
        if let local {NSEvent.removeMonitor(local);self.local=nil}
    }
    deinit {invalidate()}
}

/// Fn cannot be represented faithfully by the Carbon key-chord backend. This optional,
/// permission-gated tap consumes only the configured Fn key and its paired repeats/up;
/// every other key, including drawing commands, passes through unchanged.
struct FnShortcutState {
    private var observed: ObservedShortcutState
    private let code: UInt16
    private var consumed = false
    init(shortcut:ActivationShortcut,awaitNeutral:Bool=false) {
        observed=ObservedShortcutState(shortcut:shortcut,awaitNeutral:awaitNeutral);code=shortcut.keyCode!
    }
    mutating func handle(type:NSEvent.EventType,flags:UInt64,keyCode:UInt16,repeatKey:Bool=false)->(fire:Bool,consume:Bool) {
        let trigger=observed.handle(type:type,flags:flags,keyCode:keyCode,repeatKey:repeatKey)
        if type == .keyUp,keyCode == code,consumed {consumed=false;return(false,true)}
        if type == .keyDown,keyCode == code {
            if consumed{return(false,true)}
            if trigger {consumed=true;return(true,true)}
        }
        return(false,false)
    }
}

private final class FnShortcutRegistration: ShortcutRegistration {
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var state: FnShortcutState
    private let shortcut: ActivationShortcut
    private let fire: () -> Void
    init(shortcut:ActivationShortcut,fire:@escaping () -> Void) throws {
        self.fire=fire;self.shortcut=shortcut
        state=FnShortcutState(shortcut:shortcut,awaitNeutral:!NSEvent.modifierFlags.intersection(ActivationShortcut.modifierMask).isEmpty)
        guard AXIsProcessTrusted() else{throw ShortcutFailure.accessibility}
        let mask=CGEventMask((1<<CGEventType.flagsChanged.rawValue)|(1<<CGEventType.keyDown.rawValue)|(1<<CGEventType.keyUp.rawValue))
        port=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:mask,callback:{_,type,event,context in
            guard let context else{return Unmanaged.passUnretained(event)}
            let owner=Unmanaged<FnShortcutRegistration>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                owner.state=FnShortcutState(shortcut:owner.shortcut,awaitNeutral:!NSEvent.modifierFlags.intersection(ActivationShortcut.modifierMask).isEmpty)
                if let port=owner.port {CGEvent.tapEnable(tap:port,enable:true)}
                return Unmanaged.passUnretained(event)
            }
            let kind:NSEvent.EventType
            switch type {case .keyDown:kind = .keyDown;case .keyUp:kind = .keyUp;case .flagsChanged:kind = .flagsChanged;default:return Unmanaged.passUnretained(event)}
            let result=owner.state.handle(type:kind,flags:event.flags.rawValue,keyCode:UInt16(truncatingIfNeeded:event.getIntegerValueField(.keyboardEventKeycode)),repeatKey:event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            if result.fire{DispatchQueue.main.async{[weak owner] in owner?.fire()}}
            return result.consume ? nil:Unmanaged.passUnretained(event)
        },userInfo:Unmanaged.passUnretained(self).toOpaque())
        guard let port else{throw ShortcutFailure.accessibility}
        source=CFMachPortCreateRunLoopSource(kCFAllocatorDefault,port,0)
        guard let source else{invalidate();throw ShortcutFailure.unavailable(-1)}
        CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes)
        CGEvent.tapEnable(tap:port,enable:true)
    }
    func invalidate() {
        if let port{CGEvent.tapEnable(tap:port,enable:false);CFMachPortInvalidate(port);self.port=nil}
        if let source{CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes);self.source=nil}
    }
    deinit {invalidate()}
}
