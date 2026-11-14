// SPDX-License-Identifier: MIT
import Foundation

/// Import only LeviOsa-owned preferences once. Never import TCC grants, diagnostics or Sparkle identifiers.
enum PreferencesUpgrade {
    static let marker="reviewPreferencesImported"
    static let keys=["cornerEnabled","corner","activationShortcut","shortcutDisabled","checkForUpdates"]
    static func importReview(_ review:[String:Any]?,into defaults:UserDefaults){
        guard defaults.object(forKey:marker) == nil else{return}
        for key in keys where defaults.object(forKey:key) == nil {
            if let value=review?[key]{defaults.set(value,forKey:key)}
        }
        defaults.set(true,forKey:marker)
    }
}
