import AppKit
import Carbon

let ctrl=UInt64(NSEvent.ModifierFlags.control.rawValue)
let option=UInt64(NSEvent.ModifierFlags.option.rawValue)
let command=UInt64(NSEvent.ModifierFlags.command.rawValue)
let shift=UInt64(NSEvent.ModifierFlags.shift.rawValue)
let fn=UInt64(NSEvent.ModifierFlags.function.rawValue)
let custom=ActivationShortcut(modifiers:ctrl|option,keyCode:40,keyLabel:"K")
assert(ActivationShortcut.defaultValue.title=="⌃⌥G" && custom.title=="⌃⌥K")
assert(custom.carbonModifiers==UInt32(controlKey|optionKey))
assert(!ActivationShortcut(modifiers:0,keyCode:40,keyLabel:"K").isValid)
assert(!ActivationShortcut(modifiers:shift,keyCode:40,keyLabel:"K").isValid)
assert(!ActivationShortcut(modifiers:ctrl,keyCode:53,keyLabel:"Esc").isValid)
assert(!ActivationShortcut(modifiers:ctrl,keyCode:55,keyLabel:"⌘").isValid)
assert(!ActivationShortcut(modifiers:ctrl,keyCode:128,keyLabel:"Bad").isValid)
assert(!ActivationShortcut(modifiers:ctrl|(1<<3),keyCode:40,keyLabel:"K").isValid)
let modifiers=ActivationShortcut(modifiers:ctrl|option,keyCode:nil,keyLabel:"")
let fnKey=ActivationShortcut(modifiers:fn|command,keyCode:40,keyLabel:"K")
assert(modifiers.isValid && modifiers.needsObservation && fnKey.needsObservation)
assert(!custom.needsObservation)
print("PASS: shortcut validation, modifier display, Carbon mapping, Fn/modifier-only routing")

var record=ShortcutRecordingState()
if case .invalid=record.keyDown(code:40,flags:0,label:"K") {} else{assertionFailure()}
_ = record.flagsChanged(ctrl|option)
if case .save(let value)=record.keyDown(code:40,flags:ctrl|option,label:"K"){assert(value==custom)}else{assertionFailure()}
// A rejected registration's modifier releases must not accidentally save another shortcut.
if case .waiting=record.flagsChanged(ctrl) {} else{assertionFailure()}
if case .waiting=record.flagsChanged(0) {} else{assertionFailure()}
if case .cancel=record.keyDown(code:53,flags:0,label:"Esc") {} else{assertionFailure()}
var modifierRecord=ShortcutRecordingState()
_ = modifierRecord.flagsChanged(ctrl);_ = modifierRecord.flagsChanged(ctrl|option)
_ = modifierRecord.flagsChanged(option)
if case .save(let value)=modifierRecord.flagsChanged(0){assert(value==modifiers)}else{assertionFailure()}
var arrowRecord=ShortcutRecordingState()
if case .save(let value)=arrowRecord.keyDown(code:123,flags:ctrl|fn,label:"←"){assert(value.modifiers==ctrl)}else{assertionFailure()}
var fnRecord=ShortcutRecordingState();_ = fnRecord.flagsChanged(fn)
if case .save(let value)=fnRecord.keyDown(code:40,flags:fn|command,label:"K"){assert(value==fnKey)}else{assertionFailure()}
print("PASS: key/modifier recording, Escape, failed-choice release isolation, implicit arrow Fn flag")

var observed=ObservedShortcutState(shortcut:modifiers)
assert(!observed.handle(type:.flagsChanged,flags:ctrl,keyCode:59))
assert(!observed.handle(type:.flagsChanged,flags:ctrl|option,keyCode:58))
assert(!observed.handle(type:.flagsChanged,flags:option,keyCode:59))
assert(observed.handle(type:.flagsChanged,flags:0,keyCode:58))
assert(!observed.handle(type:.flagsChanged,flags:0,keyCode:58))
_ = observed.handle(type:.flagsChanged,flags:ctrl|option,keyCode:58)
_ = observed.handle(type:.keyDown,flags:ctrl|option,keyCode:8)
assert(!observed.handle(type:.flagsChanged,flags:0,keyCode:58))
_ = observed.handle(type:.flagsChanged,flags:ctrl|option|shift,keyCode:56)
_ = observed.handle(type:.flagsChanged,flags:ctrl|option,keyCode:56)
assert(!observed.handle(type:.flagsChanged,flags:0,keyCode:58))
var awaiting=ObservedShortcutState(shortcut:modifiers,awaitNeutral:true)
_ = awaiting.handle(type:.flagsChanged,flags:ctrl|option,keyCode:58)
assert(!awaiting.handle(type:.flagsChanged,flags:0,keyCode:58))
_ = awaiting.handle(type:.flagsChanged,flags:ctrl|option,keyCode:58)
assert(awaiting.handle(type:.flagsChanged,flags:0,keyCode:58))
var observedFn=ObservedShortcutState(shortcut:fnKey)
_ = observedFn.handle(type:.flagsChanged,flags:fn|command,keyCode:63)
assert(observedFn.handle(type:.keyDown,flags:fn|command,keyCode:40))
assert(!observedFn.handle(type:.keyDown,flags:fn|command,keyCode:40,repeatKey:true))
_ = observedFn.handle(type:.keyUp,flags:fn|command,keyCode:40)
assert(observedFn.handle(type:.keyDown,flags:fn|command,keyCode:40))
print("PASS: modifier-only release, typing/extra-modifier rejection, neutral gate and Fn repeat latch")

var fnInput=FnShortcutState(shortcut:fnKey)
_ = fnInput.handle(type:.flagsChanged,flags:fn|command,keyCode:63)
assert(!fnInput.handle(type:.keyDown,flags:0,keyCode:8).consume)
assert(!fnInput.handle(type:.keyDown,flags:0,keyCode:36).consume)
assert(!fnInput.handle(type:.keyDown,flags:0,keyCode:53).consume)
let fnDown=fnInput.handle(type:.keyDown,flags:fn|command,keyCode:40)
assert(fnDown.fire && fnDown.consume)
assert(fnInput.handle(type:.keyDown,flags:0,keyCode:40,repeatKey:true).consume)
assert(!fnInput.handle(type:.keyDown,flags:fn|command,keyCode:8).consume)
assert(fnInput.handle(type:.keyUp,flags:0,keyCode:40).consume)
_ = fnInput.handle(type:.flagsChanged,flags:0,keyCode:63)
assert(!fnInput.handle(type:.keyDown,flags:0,keyCode:40).consume)
print("PASS: optional Fn tap consumes only its matching key/repeats/up; C/Enter/Escape and normal typing pass through")

final class FakeRegistration: ShortcutRegistration {
    var invalidated=false
    let fire: () -> Void
    init(_ fire:@escaping () -> Void){self.fire=fire}
    func invalidate(){invalidated=true}
}
let suite="local.maxim.leviosa.shortcut-tests."+UUID().uuidString
let defaults=UserDefaults(suiteName:suite)!
defer{defaults.removePersistentDomain(forName:suite)}
var installed=[FakeRegistration]();var reject:ActivationShortcut?
let service=ShortcutService(defaults:defaults,factory:{value,_,fire in
    if value == reject {throw ShortcutFailure.unavailable(-9878)}
    let registration=FakeRegistration(fire);installed.append(registration);return registration
})
var triggers=0;service.onTrigger={triggers += 1}
assert(service.shortcut == .defaultValue && service.enabled)
assert(service.start()==nil && installed.count==1);installed[0].fire();assert(triggers==1)
assert(service.change(to:custom)==nil && installed[0].invalidated)
installed[0].fire();assert(triggers==1);installed[1].fire();assert(triggers==2)
assert(ActivationShortcut.load(from:defaults)==custom)
reject = .defaultValue
assert(service.change(to:.defaultValue) != nil && service.shortcut==custom && !installed[1].invalidated)
assert(ActivationShortcut.load(from:defaults)==custom)
service.pause();installed[1].fire();assert(triggers==2 && installed[1].invalidated)
reject=nil
assert(service.change(to:.defaultValue)==nil && service.paused)
installed[2].fire();assert(triggers==2)
assert(service.resume()==nil);installed[2].fire();assert(triggers==3)
assert(service.setEnabled(false)==nil && installed[2].invalidated && defaults.bool(forKey:"shortcutDisabled"))
assert(service.change(to:custom)==nil && installed.count==3)
reject=custom
assert(service.setEnabled(true) != nil && !service.enabled && defaults.bool(forKey:"shortcutDisabled"))
reject=nil
assert(service.setEnabled(true)==nil);installed.last!.fire();assert(triggers==4)
service.stop();installed.last!.fire();assert(triggers==4)
defaults.set(Data("corrupt".utf8),forKey:ActivationShortcut.storageKey)
assert(ActivationShortcut.load(from:defaults) == .defaultValue)
ActivationShortcut(modifiers:0,keyCode:40,keyLabel:"K").save(to:defaults)
assert(ActivationShortcut.load(from:defaults) == .defaultValue)
print("PASS: transactional replacement, conflict preservation, recording suspension, stale callbacks, disable/enable, persistence and corrupt-store fallback")
