// SPDX-License-Identifier: MIT
import AppKit

final class CommandRegistration: DrawingCommandRegistration {
    var isEnabled = true
    var removed = 0
    func invalidate() { isEnabled = false; removed += 1 }
}
let fakeTap: DrawingKeyboard.TapFactory = { _, _, _ in CommandRegistration() }

func key(_ code: UInt16, _ text: String, flags: NSEvent.ModifierFlags = [], type: NSEvent.EventType = .keyDown) -> NSEvent {
    NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
        timestamp: 0, windowNumber: 0, context: nil, characters: text,
        charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
}
let enter = key(36, "\r"), keypadEnter = key(76, "\u{3}"), clear = key(8, "c"), escape = key(53, "\u{1b}")
var callback: DrawingKeyboard.Handler?
var removed = 0, ready = true
var commands = [DrawingCommand]()
var readinessSeen = [Bool]()
let keyboard = DrawingKeyboard(install: { callback = $0; return NSObject() }, remove: { _ in removed += 1 }, makeTap: fakeTap)
assert(keyboard.start(isReady: { ready }, received: { _, value in readinessSeen.append(value) }, command: { commands.append($0) }))
assert(keyboard.isMonitoring)
for event in [enter, keypadEnter, clear, key(8, "C", flags: .shift)] { assert(callback!(event) == nil) }
assert(commands == [.submit, .submit, .clear, .clear])
for event in [key(8, "c", flags: .command), key(36, "\r", flags: .control), key(53, "\u{1b}", flags: .option), key(0, "a"),
              key(8, "c", type: .keyUp), key(8, "c", flags: .command, type: .flagsChanged)] {
    assert(callback!(event) === event)
}
ready = false
assert(callback!(enter) === enter && callback!(clear) === clear && commands.count == 4)
assert(callback!(escape) == nil && commands.count == 5 && commands.last == .cancel)
assert(readinessSeen.last == false)
let observedBeforeStop = readinessSeen.count
ready = true
let stale = callback!
keyboard.stop();keyboard.stop()
assert(!keyboard.isMonitoring && removed == 1 && stale(enter) === enter)
assert(readinessSeen.count == observedBeforeStop)
assert(keyboard.start(isReady: { true }, command: { command in commands.append(command); keyboard.stop() }))
assert(stale(clear) === clear)
assert(callback!(escape) == nil && commands.last == .cancel && removed == 2 && !keyboard.isMonitoring)
assert(callback!(clear) === clear)
print("PASS: scoped commands, unchanged typing/modifier shortcuts, submit/clear focus gating, recovery Escape despite failed readiness, stale callback isolation")

let unavailable = DrawingKeyboard(install: { _ in nil }, remove: { _ in assertionFailure("No monitor was acquired") }, makeTap: fakeTap)
assert(!unavailable.start(isReady: { true }, command: { _ in assertionFailure() }) && !unavailable.isMonitoring)
var weakCallback: DrawingKeyboard.Handler?
do {
    let scoped = DrawingKeyboard(install: { weakCallback = $0; return NSObject() }, remove: { _ in removed += 1 }, makeTap: fakeTap)
    assert(scoped.start(isReady: { true }, command: { _ in assertionFailure("Stale callback") }))
}
assert(removed == 3 && weakCallback!(escape) === escape)
print("PASS: failed installation and deinitialization leave no command ownership")

// Exercise the actual AppKit application-dispatch boundary, with no visible window
// and no system-wide input injection. These events deliberately have windowNumber 0.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let native = DrawingKeyboard(makeTap: fakeTap)
var delivered = [DrawingCommand]()
for _ in 0..<20 {
    assert(native.start(isReady: { true }, command: { delivered.append($0) }))
    app.sendEvent(enter);app.sendEvent(clear);app.sendEvent(escape)
    native.stop()
}
assert(delivered == Array(repeating: [.submit, .clear, .cancel], count: 20).flatMap { $0 })
print("PASS: real AppKit local dispatch receives windowless Enter/C/Escape across 20 sessions")

// The upstream route delivers even when the local callback receives nothing.
// These are injected callbacks, not physical or WindowServer delivery evidence.
var upstreamReady: (() -> Bool)!, upstream: ((DrawingCommand) -> Void)!, interrupted: (() -> Void)!
var registrations = [CommandRegistration]()
var commandsFromUpstream = [DrawingCommand](), failures = 0
let upstreamKeyboard = DrawingKeyboard(install: { _ in NSObject() }, remove: { _ in }, makeTap: { gate, send, fail in
    upstreamReady = gate; upstream = send; interrupted = fail
    let registration = CommandRegistration(); registrations.append(registration); return registration
})
assert(!upstreamKeyboard.systemCommandsEnabled)
for _ in 0..<100 {
    ready = true
    assert(upstreamKeyboard.start(isReady: { ready }, unavailable: { failures += 1 }, command: { commandsFromUpstream.append($0) }))
    assert(upstreamReady() && upstreamKeyboard.systemCommandsEnabled)
    let old = upstream!, oldFailure = interrupted!, oldGate = upstreamReady!
    upstream(.clear); upstream(.submit); upstream(.cancel)
    ready = false; upstream(.clear); assert(!upstreamReady())
    upstreamKeyboard.stop()
    assert(!upstreamKeyboard.systemCommandsEnabled && registrations.last!.removed == 1)
    ready = true; old(.submit); oldFailure(); assert(!oldGate())
}
assert(commandsFromUpstream == Array(repeating: [.clear, .submit, .cancel], count: 100).flatMap { $0 } && failures == 0)
let noTap = DrawingKeyboard(install: { _ in assertionFailure("Do not enter local-only capture"); return nil }, makeTap: { _, _, _ in nil })
assert(!noTap.start(isReady: { true }, command: { _ in assertionFailure() }))
let rollback = CommandRegistration()
let noLocal = DrawingKeyboard(install: { _ in nil }, makeTap: { _, _, _ in rollback })
assert(!noLocal.start(isReady: { true }, command: { _ in assertionFailure() }) && rollback.removed == 1)
let disabled = CommandRegistration(); disabled.isEnabled = false
let disabledKeyboard = DrawingKeyboard(install: { _ in assertionFailure("Disabled tap must not begin capture"); return nil }, makeTap: { _, _, _ in disabled })
assert(!disabledKeyboard.start(isReady: { true }, command: { _ in assertionFailure() }) && disabled.removed == 1)
ready = true
assert(upstreamKeyboard.start(isReady: { ready }, unavailable: { failures += 1; upstreamKeyboard.stop() }, command: { _ in assertionFailure() }))
interrupted()
assert(failures == 1 && !upstreamKeyboard.systemCommandsEnabled && registrations.last!.removed == 1)
print("PASS: upstream-only dispatch across 100 sessions, readiness, stale callbacks, denied/disabled access, interruption and partial acquisition rollback")

var keys = DrawingCommandKeyState(clearCodes: [8, 34])
for code: UInt16 in [36, 76, 53, 8, 34] {
    assert(keys.handle(type: .keyDown, code: code, flags: [], repeatKey: false, ready: true).command != nil)
    assert(keys.handle(type: .keyDown, code: code, flags: [], repeatKey: true, ready: true).consume)
    assert(keys.handle(type: .keyUp, code: code, flags: .maskCommand, repeatKey: false, ready: true).consume)
    assert(!keys.handle(type: .keyUp, code: code, flags: [], repeatKey: false, ready: true).consume)
}
for flags: CGEventFlags in [.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn] {
    assert(!keys.handle(type: .keyDown, code: 8, flags: flags, repeatKey: false, ready: true).consume)
}
assert(!keys.handle(type: .keyDown, code: 0, flags: [], repeatKey: false, ready: true).consume)
assert(!keys.handle(type: .keyDown, code: 8, flags: [], repeatKey: false, ready: false).consume)
assert(!keys.handle(type: .keyDown, code: 8, flags: [], repeatKey: true, ready: true).consume)
assert(keys.handle(type: .keyDown, code: 8, flags: .maskShift, repeatKey: false, ready: true).command == .clear)
assert(!keys.handle(type: .keyUp, code: 8, flags: [], repeatKey: false, ready: false).consume)
print("PASS: command-only filtering, layout C keys, held/repeated keys, modifier shortcuts and focus loss passthrough")
