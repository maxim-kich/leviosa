// SPDX-License-Identifier: MIT
import AppKit
/// Foreground-only pointer lock and one balanced hide/show pair, owned by the same session.
/// Keyboard input and raw trackpad contacts are not intercepted.
final class DrawingCursor {
    // A real transparent bitmap, not an empty NSImage that AppKit may replace with an arrow.
    static let transparent: NSCursor = {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:16,pixelsHigh:16,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:64,bitsPerPixel:32)!
        bitmap.bitmapData!.initialize(repeating:0,count:bitmap.bytesPerRow*bitmap.pixelsHigh)
        let image=NSImage(size:NSSize(width:16,height:16));image.addRepresentation(bitmap)
        return NSCursor(image:image,hotSpot:.zero)
    }()
    private(set) var hidden = false
    private(set) var locked = false
    private(set) var appearanceActive = false
    private weak var appearanceWindow: NSWindow?
    var ownsResources: Bool { hidden || locked || appearanceActive }
    private var original: CGPoint?
    private var restoreRequested = false
    private let hide: () -> CGError
    private let show: () -> CGError
    private let warp: (CGPoint) -> Void
    private let associate: (Bool) -> CGError
    init(hide: @escaping () -> CGError = { CGDisplayHideCursor(CGMainDisplayID()) },
         show: @escaping () -> CGError = { CGDisplayShowCursor(CGMainDisplayID()) },
         warp: @escaping (CGPoint) -> Void = { _ = CGWarpMouseCursorPosition($0) },
         associate: @escaping (Bool) -> CGError = { CGAssociateMouseAndMouseCursorPosition($0 ? 1 : 0) }) {
        self.hide=hide;self.show=show;self.warp=warp;self.associate=associate
    }
    func acquire(window: NSWindow, pad: Pad) -> Bool {
        if hidden && locked && appearanceActive { return true }
        guard NSApp.isActive, NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier, window.isKeyWindow, window.firstResponder === pad, window.isOnActiveSpace else { return false }
        let location = NSEvent.mouseLocation
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let original = CGPoint(x: location.x, y: top-location.y)
        let center = window.convertPoint(toScreen: pad.convert(NSPoint(x: pad.bounds.midX, y: pad.bounds.midY), to: nil))
        guard acquire(ready:true,original:original,placement:CGPoint(x:center.x,y:top-center.y)) else{return false}
        // Cursor rectangles can replace the current image independently of pointer lock.
        // Only this disposable drawing window stops managing them; Settings is untouched.
        appearanceWindow=window;window.disableCursorRects();appearanceActive=true
        refreshAppearance();return true
    }
    func refreshAppearance() {
        guard appearanceActive,hidden,locked,let window=appearanceWindow,
              NSApp.isActive,window.isKeyWindow,window.isOnActiveSpace,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else{return}
        // Idempotent image selection. Never add another hide or push onto the cursor stack.
        Self.transparent.set()
    }
    // The resource operation is injectable, so cleanup/error counts can be tested without hiding the real cursor.
    func acquire(ready:Bool,original:CGPoint,placement:CGPoint)->Bool {
        if hidden && locked { return true }
        guard ready,!ownsResources,hide() == .success else{return false}
        self.original=original;hidden=true
        // Place inside the drawing surface before locking. Absolute pointer motion stops;
        // raw MultitouchSupport contacts continue independently of pointer position.
        warp(placement)
        guard associate(false) == .success else { release(); return false }
        locked=true;return true
    }
    @discardableResult func release(restorePosition:Bool=true)->Bool {
        guard ownsResources else { return true }
        restoreRequested = restoreRequested || restorePosition
        // Reconnect before showing. Attempt both cleanups even if one fails; retain
        // failed ownership for retry rather than taking another hide/lock next session.
        if locked,associate(true) == .success { locked=false }
        if !locked,restoreRequested,let original { warp(original);self.original=nil }
        if appearanceActive {
            appearanceActive=false
            appearanceWindow?.enableCursorRects();appearanceWindow=nil
            NSCursor.arrow.set()
        }
        if hidden,show() == .success { hidden=false }
        if !ownsResources { original=nil;restoreRequested=false }
        return !ownsResources
    }
    deinit { release() }
}
