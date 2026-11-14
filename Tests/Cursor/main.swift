import AppKit
// A cursor with no bitmap representation may fall back to an arrow. Verify real alpha pixels.
let representations=DrawingCursor.transparent.image.representations.compactMap{$0 as? NSBitmapImageRep}
assert(!representations.isEmpty)
for bitmap in representations {
    assert(bitmap.hasAlpha && bitmap.pixelsWide>0 && bitmap.pixelsHigh>0)
    for y in 0..<bitmap.pixelsHigh {for x in 0..<bitmap.pixelsWide {assert(bitmap.colorAt(x:x,y:y)!.alphaComponent==0)}}
}
print("PASS: drawing cursor has a real fully transparent bitmap")
var hides=0,shows=0;var warps=[CGPoint]();var associations=[Bool]()
let origin=CGPoint(x:-200,y:30),center=CGPoint(x:100,y:100)
let cursor=DrawingCursor(hide:{hides += 1;return .success},show:{shows += 1;return .success},warp:{warps.append($0)},associate:{associations.append($0);return .success})
assert(!cursor.acquire(ready:false,original:origin,placement:center));assert(hides==0 && warps.isEmpty && associations.isEmpty)
assert(cursor.acquire(ready:true,original:origin,placement:center))
assert(cursor.acquire(ready:true,original:origin,placement:center));assert(hides==1 && shows==0 && cursor.hidden && cursor.locked)
cursor.release();cursor.release();assert(shows==1 && !cursor.ownsResources && warps==[center,origin] && associations==[false,true])
let failed=DrawingCursor(hide:{.failure},show:{shows += 1;return .success},warp:{_ in assertionFailure()},associate:{_ in assertionFailure();return .failure})
assert(!failed.acquire(ready:true,original:origin,placement:center));failed.release();assert(shows==1)
for _ in 0..<20{assert(cursor.acquire(ready:true,original:origin,placement:center));cursor.release()}
assert(hides==21 && shows==21 && associations.count==42)
print("PASS: foreground readiness, single lock/hide ownership, balanced cleanup, failed hide, pointer restoration and 20 repeated sessions")

var order=[String]()
let ordered=DrawingCursor(hide:{order.append("hide");return .success},show:{order.append("show");return .success},warp:{order.append($0==origin ? "restore":"place")},associate:{order.append($0 ? "unlock":"lock");return .success})
assert(ordered.acquire(ready:true,original:origin,placement:center));ordered.release()
assert(order==["hide","place","lock","unlock","restore","show"])
print("PASS: placement precedes pointer lock; unlock and restoration precede showing")

var focusWarps=[CGPoint]()
let focusLoss=DrawingCursor(hide:{.success},show:{.success},warp:{focusWarps.append($0)},associate:{_ in .success})
assert(focusLoss.acquire(ready:true,original:origin,placement:center))
assert(focusLoss.release(restorePosition:false) && !focusLoss.ownsResources && focusWarps==[center])
print("PASS: focus/Space cancellation unlocks without warping back to the starting desktop")

var rollback=[String]()
let failedLock=DrawingCursor(hide:{rollback.append("hide");return .success},show:{rollback.append("show");return .success},warp:{rollback.append($0==origin ? "restore":"place")},associate:{_ in rollback.append("lock-failed");return .failure})
assert(!failedLock.acquire(ready:true,original:origin,placement:center))
assert(!failedLock.ownsResources && rollback==["hide","place","lock-failed","restore","show"])
print("PASS: failed pointer lock rolls back hiding and original position")

var attempts=0;var retryAssociations=[Bool]()
let retry=DrawingCursor(hide:{.success},show:{attempts += 1;return attempts==1 ? .failure:.success},warp:{_ in},associate:{retryAssociations.append($0);return .success})
assert(retry.acquire(ready:true,original:origin,placement:center))
assert(!retry.release(restorePosition:false) && retry.hidden && !retry.locked)
assert(!retry.acquire(ready:true,original:origin,placement:center))
assert(retry.release(restorePosition:false) && !retry.ownsResources && attempts==2 && retryAssociations==[false,true])
print("PASS: rejected show retains hide ownership without duplicating pointer lock")

var unlockAttempts=0;var unlockShows=0;var unlockWarps=[CGPoint]()
let retryUnlock=DrawingCursor(hide:{.success},show:{unlockShows += 1;return .success},warp:{unlockWarps.append($0)},associate:{connected in
    guard connected else{return .success};unlockAttempts += 1;return unlockAttempts==1 ? .failure:.success
})
assert(retryUnlock.acquire(ready:true,original:origin,placement:center))
assert(!retryUnlock.release() && retryUnlock.locked && !retryUnlock.hidden && unlockShows==1 && unlockWarps==[center])
assert(!retryUnlock.acquire(ready:true,original:origin,placement:center))
assert(retryUnlock.release(restorePosition:false) && !retryUnlock.ownsResources && unlockShows==1 && unlockWarps==[center,origin])
print("PASS: rejected unlock still shows the cursor and retains unlock/restoration for retry")

var deinitCalls=[Bool]()
do {
    let scoped=DrawingCursor(hide:{.success},show:{.success},warp:{_ in},associate:{deinitCalls.append($0);return .success})
    assert(scoped.acquire(ready:true,original:origin,placement:center))
}
assert(deinitCalls==[false,true])
print("PASS: deinitialization releases pointer lock")
