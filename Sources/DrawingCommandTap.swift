// SPDX-License-Identifier: MIT
import AppKit
import Carbon

protocol DrawingCommandRegistration: AnyObject {
    var isEnabled: Bool { get }
    func invalidate()
}

/// A small, session-owned filter. It never captures ordinary typing or modified
/// shortcuts. A consumed key stays consumed through repeats/release, exactly once.
struct DrawingCommandKeyState {
    let clearCodes: Set<UInt16>
    private var held = Set<UInt16>()
    init(clearCodes: Set<UInt16> = [8]) { self.clearCodes = clearCodes }
    mutating func handle(type: CGEventType, code: UInt16, flags: CGEventFlags,
                         repeatKey: Bool, ready: Bool) -> (consume: Bool, command: DrawingCommand?) {
        guard ready else { held.removeAll(); return (false, nil) }
        if type == .keyUp { return (held.remove(code) != nil, nil) }
        guard type == .keyDown else { return (false, nil) }
        if held.contains(code) { return (true, nil) }
        guard ready, !repeatKey,
              flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]).isEmpty else { return (false, nil) }
        let action: DrawingCommand?
        switch code {
        case 36, 76: action = .submit
        case 53: action = .cancel
        default: action = clearCodes.contains(code) ? .clear : nil
        }
        guard let action else { return (false, nil) }
        held.insert(code)
        return (true, action)
    }
}

/// Receives drawing commands before WindowServer's application/window routing.
/// Installed only for a foreground drawing session; removed before pointer unlock.
/// Accessibility is checked without prompting. All non-command events pass through.
final class DrawingCommandTap: DrawingCommandRegistration {
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var state = DrawingCommandKeyState(clearCodes: DrawingCommandTap.clearKeyCodes())
    private let ready: () -> Bool
    private let command: (DrawingCommand) -> Void
    private let unavailable: () -> Void
    private var alive = true
    var isEnabled: Bool { alive && !IsSecureEventInputEnabled() && port.map { CGEvent.tapIsEnabled(tap: $0) } == true }

    init?(ready: @escaping () -> Bool, command: @escaping (DrawingCommand) -> Void,
          unavailable: @escaping () -> Void) {
        self.ready = ready; self.command = command; self.unavailable = unavailable
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled() else { return nil }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<DrawingCommandTap>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let port else { return nil }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { invalidate(); return nil }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        guard isEnabled else { invalidate(); return nil }
    }
    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard alive else { return Unmanaged.passUnretained(event) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // End the session rather than leave a locked cursor with a dead keyboard.
            alive = false
            DispatchQueue.main.async { [weak self] in self?.unavailable() }
            return Unmanaged.passUnretained(event)
        }
        let result = state.handle(type: type,
            code: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags, repeatKey: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, ready: ready())
        if let action = result.command {
            // Do no UI work, logging or lifecycle mutation in the event-tap callback.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.alive, self.ready() else { return }
                self.command(action)
            }
        }
        return result.consume ? nil : Unmanaged.passUnretained(event)
    }
    func invalidate() {
        alive = false
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port); self.port = nil }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes); self.source = nil }
    }
    deinit { invalidate() }

    /// Resolve the unmodified C key in the active hardware layout once per session.
    /// Input methods without layout data fall back to the physical ANSI C key.
    private static func clearKeyCodes() -> Set<UInt16> {
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else { return [8] }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return [8] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var codes = Set<UInt16>()
        for code in UInt16(0)..<128 {
            var dead: UInt32 = 0, length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
            if result == noErr, String(utf16CodeUnits: chars, count: length).lowercased() == "c" { codes.insert(code) }
        }
        return codes.isEmpty ? [8] : codes
    }
}
