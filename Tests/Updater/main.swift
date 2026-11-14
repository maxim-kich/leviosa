import AppKit
assert(ReleaseVersion("v1.2.3")! > ReleaseVersion("0.1.0")!)
assert(ReleaseVersion("1.2") == nil)
let archive=PublishedRelease.Asset(name:"LeviOsa-v0.2.0-macOS-arm64.zip",browser_download_url:URL(string:"https://github.com/maxim-kich/leviosa/releases/download/v0.2.0/LeviOsa-v0.2.0-macOS-arm64.zip")!,size:100,state:"uploaded")
let feed=PublishedRelease.Asset(name:"appcast.xml",browser_download_url:URL(string:"https://github.com/maxim-kich/leviosa/releases/download/v0.2.0/appcast.xml")!,size:100,state:"uploaded")
let release=PublishedRelease(tag_name:"v0.2.0",draft:false,prerelease:false,html_url:URL(string:"https://github.com/maxim-kich/leviosa/releases/tag/v0.2.0")!,assets:[archive,feed])
assert(release.update(current:"0.1.0")?.version == "0.2.0")
let spoof=PublishedRelease(tag_name:release.tag_name,draft:false,prerelease:false,html_url:URL(string:"https://example.com/maxim-kich/leviosa/releases/tag/v0.2.0")!,assets:[archive,feed])
assert(spoof.update(current:"0.1.0") == nil)
assert(UpdateActivity(selection:true).restartBlock != nil)
let updater=UpdateChecker();updater.check();assert(updater.message.contains("not configured"));assert(!updater.checking)
print("PASS: update version/host validation, drawing restart guard, missing signing key fails closed")

// Exercise consent and asynchronous restart acknowledgement without running an installer.
import Sparkle
let suite="LeviOsa.UpdateTests.\(UUID().uuidString)"
let defaults=UserDefaults(suiteName:suite)!
defer{defaults.removePersistentDomain(forName:suite)}
let offered=ReleaseUpdate(version:"0.2.0",archive:archive.browser_download_url,length:100,feed:feed.browser_download_url)
func staged(_ confirm:@escaping(String,String,String)->Bool = {_,_,_ in true})->UpdateChecker {
 let checker=UpdateChecker(defaults:defaults,confirm:confirm)
 checker.activity={UpdateActivity()}
 checker.offerUpdate(offered){_ in};checker.openUpdate()
 return checker
}
do {
 let checker=staged();var reply:SPUUserUpdateChoice?
 checker.showReady(toInstallAndRelaunch:{reply=$0})
 var complete:((Bool)->Void)?;var valid:(()->Bool)?;var abandoned=false
 checker.beforeRestart={current,done in valid=current;complete=done}
 checker.abandonRestart={abandoned=true}
 checker.openUpdate()
 assert(checker.phase == .preparing && !checker.restartAuthorized && reply == nil)
 assert(!checker.permitsTermination() && valid?() == true)
 checker.cancel();assert(abandoned && valid?() == false)
 complete?(true)
 assert(reply == .skip && !checker.restartAuthorized && checker.permitsTermination())
}
do {
 let checker=staged();var reply:SPUUserUpdateChoice?;var attempts=0
 checker.showReady(toInstallAndRelaunch:{reply=$0})
 checker.beforeRestart={_,done in attempts += 1;done(attempts>1)}
 checker.openUpdate();assert(checker.phase == .ready && reply == nil)
 checker.openUpdate();assert(reply == .install && checker.restartAuthorized && checker.permitsTermination())
 var restored=false;checker.abandonRestart={restored=true}
 checker.showUpdaterError(NSError(domain:"test",code:1)){}
 assert(restored && !checker.restartAuthorized)
}
do {
 var activity=UpdateActivity();var complete:((Bool)->Void)?;var replies=[SPUUserUpdateChoice]()
 let checker=staged();checker.activity={activity}
 checker.showReady(toInstallAndRelaunch:{replies.append($0)})
 checker.beforeRestart={_,done in complete=done};checker.openUpdate()
 activity.unsavedGesture=true;complete?(true)
 assert(checker.phase == .ready && replies.isEmpty && !checker.restartAuthorized)
 activity.unsavedGesture=false
 checker.beforeRestart={_,done in done(true);done(true)};checker.openUpdate()
 assert(replies == [.install])
}
do {
 var checker:UpdateChecker!
 checker=staged{_,_,button in if button == "Restart"{checker.cancel()};return true}
 var replies=[SPUUserUpdateChoice]();checker.showReady(toInstallAndRelaunch:{replies.append($0)})
 checker.openUpdate();assert(replies == [.skip] && !checker.restartAuthorized)
}
assert(UpdateActivity(shortcutRecording:true).restartBlock != nil)
assert(UpdateActivity(unsavedGesture:true).restartBlock != nil)
print("PASS: separate restart consent, asynchronous stop acknowledgement, cancelled/stale/duplicate replies, stop retry, error rollback and dirty-draft guards")
