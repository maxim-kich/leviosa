// Real OS registration check. Does not synthesize keyboard input or alter app preferences.
import AppKit
import Carbon
let app=NSApplication.shared
if CommandLine.arguments.contains("--probe-review-binding") {
    var probe:EventHotKeyRef?
    let result=RegisterEventHotKey(37,UInt32(controlKey|optionKey),EventHotKeyID(signature:0x4C565154,id:99),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&probe)
    if let probe{UnregisterEventHotKey(probe)}
    print("Exclusive cross-process probe result: \(result); documented conflict code: \(eventHotKeyExistsErr)")
    exit(0)
}
let suite="local.maxim.leviosa.shortcut-registration."+UUID().uuidString
let defaults=UserDefaults(suiteName:suite)!
defer{defaults.removePersistentDomain(forName:suite)}
let flags=UInt64(NSEvent.ModifierFlags([.command,.control,.option,.shift]).rawValue)
let first=ActivationShortcut(modifiers:flags,keyCode:79,keyLabel:"F18")
let occupied=ActivationShortcut(modifiers:flags,keyCode:80,keyLabel:"F19")
first.save(to:defaults)
let service=ShortcutService(defaults:defaults)
assert(service.start()==nil)
defer{service.stop()}
var reserved:EventHotKeyRef?
assert(RegisterEventHotKey(80,occupied.carbonModifiers,EventHotKeyID(signature:0x4C565154,id:100),GetApplicationEventTarget(),0,&reserved)==noErr)
defer{if let reserved{UnregisterEventHotKey(reserved)}}
assert(service.change(to:occupied) != nil && service.shortcut==first)
assert(ActivationShortcut.load(from:defaults)==first)
let second=ShortcutService(defaults:defaults)
assert(second.start() != nil)
service.pause();assert(second.start()==nil)
second.stop();assert(service.resume()==nil)
service.stop()
var free:EventHotKeyRef?
assert(RegisterEventHotKey(79,first.carbonModifiers,EventHotKeyID(signature:0x4C565154,id:101),GetApplicationEventTarget(),0,&free)==noErr)
if let free{UnregisterEventHotKey(free)}
print("PASS: native Carbon registration, real occupied-shortcut preservation, recorder pause/resume and final unregister")
