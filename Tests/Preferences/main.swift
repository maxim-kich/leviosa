import Foundation
let suite="LeviOsa.PreferencesTests.\(UUID().uuidString)"
let defaults=UserDefaults(suiteName:suite)!
defer{defaults.removePersistentDomain(forName:suite)}
defaults.set(3,forKey:"corner")
let shortcut=Data([1,2,3])
PreferencesUpgrade.importReview(["cornerEnabled":true,"corner":0,"activationShortcut":shortcut,"shortcutDisabled":false,"checkForUpdates":false,"SUUpdateGroupIdentifier":"do-not-import","unrelated":"private"],into:defaults)
assert(defaults.bool(forKey:"cornerEnabled") && defaults.integer(forKey:"corner")==3)
assert(defaults.data(forKey:"activationShortcut")==shortcut)
assert(defaults.object(forKey:"SUUpdateGroupIdentifier")==nil && defaults.object(forKey:"unrelated")==nil)
defaults.set(false,forKey:"cornerEnabled")
PreferencesUpgrade.importReview(["cornerEnabled":true],into:defaults)
assert(!defaults.bool(forKey:"cornerEnabled"))
print("PASS: one-time review preference import preserves existing distribution choices and excludes unrelated/identifier data")
