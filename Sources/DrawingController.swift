// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

private final class OverlayLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
private final class DrawingWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var command: ((DrawingCommand) -> Void)?
    var maintainCursor: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        // Run after AppKit processes the event, so any cursor image it selects cannot win.
        // Escape clears this callback during cleanup, preventing a stale re-hide.
        defer { maintainCursor?() }
        if event.type == .keyDown,
           let action = DrawingCommand.decode(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers,
                    modified: !event.modifierFlags.intersection([.command, .control, .option]).isEmpty) {
            command?(action); return
        }
        // Capture accepts raw trackpad strokes and session-owned keyboard commands.
        // A press/scroll must not interact with the surface or open a context menu.
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
             .rightMouseDown, .rightMouseUp, .rightMouseDragged,
             .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel:
            return
        default: break
        }
        super.sendEvent(event)
    }
}

/// Opt-in, local QA evidence. Contains lifecycle state/counts, never strokes, text, or key contents.
final class CaptureDiagnostics {
    let directory: URL?
    let allowsQAControl = ProcessInfo.processInfo.environment["LEVIOSA_CAPTURE_DIAGNOSTICS"] != nil
    init() {
        directory = (ProcessInfo.processInfo.environment["LEVIOSA_CAPTURE_DIAGNOSTICS"]
            ?? UserDefaults.standard.string(forKey: "captureDiagnosticsDirectory")).map { URL(fileURLWithPath: $0) }
        if let directory { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }
    func record(_ event: String, controller: DrawingController, details: [String: Any] = [:]) {
        guard let directory else { return }
        let window = controller.window
        var data: [String: Any] = [
            "event": event, "time": Date().timeIntervalSince1970,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "phase": controller.lifecycle.phase.rawValue,
            "session": controller.lifecycle.token?.uuidString ?? "",
            "active": NSApp.isActive, "frontmostIsSelf": NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
            "key": window?.isKeyWindow ?? false, "padFocused": window?.firstResponder === controller.pad,
            "applicationHidden": NSApp.isHidden,
            "keyWindowNumber": NSApp.keyWindow?.windowNumber ?? -1,
            "firstResponderType": window?.firstResponder.map { String(describing: type(of: $0)) } ?? "none",
            "visible": window?.isVisible ?? false, "onActiveSpace": window?.isOnActiveSpace ?? false,
            "cursorOwned": controller.cursor.hidden,
            "keyboardOwned": controller.keyboard.isMonitoring,
            "systemCommandsEnabled": controller.keyboard.systemCommandsEnabled,
            "pointerLocked": controller.cursor.locked,
            "cursorAppearanceActive": controller.cursor.appearanceActive,
            "transparentCursorCurrent": controller.cursor.appearanceActive && NSCursor.current === DrawingCursor.transparent,
            "arrowCursorCurrent": NSCursor.current === NSCursor.arrow,
            "cursorRectsEnabled": window?.areCursorRectsEnabled ?? true,
            "joinsAllSpaces": window?.collectionBehavior.contains(.canJoinAllSpaces) ?? false,
            "movesToActiveSpace": window?.collectionBehavior.contains(.moveToActiveSpace) ?? false,
            "points": controller.pad.points.count, "strokes": controller.pad.stroke,
            "windowNumber": window?.windowNumber ?? -1,
            "frame": window.map { NSStringFromRect($0.frame) } ?? "",
            "display": controller.screen.map { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 } ?? 0
        ]
        data["runLoopMode"] = RunLoop.current.currentMode?.rawValue ?? "none"
        data["modalWindow"] = NSApp.modalWindow?.windowNumber ?? -1
        data.merge(details) { _, value in value }
        guard let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) else { return }
        try? bytes.write(to: directory.appendingPathComponent("state.json"), options: .atomic)
        let log = directory.appendingPathComponent("events.ndjson")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: log) { defer { try? file.close() }; _ = try? file.seekToEnd(); try? file.write(contentsOf: bytes + Data([10])) }
    }
    /// Only input categories and flags; never stores typed characters or arbitrary key codes.
    func received(_ event: NSEvent, ready: Bool, controller: DrawingController) {
        guard directory != nil else { return }
        let category: String
        switch event.keyCode {
        case 36, 76: category = "enter"
        case 53: category = "escape"
        case 8: category = "clear-key"
        default: category = event.type == .flagsChanged ? "modifiers" : "other"
        }
        let decoded = event.type == .keyDown ? DrawingCommand.decode(keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers,
            modified: !event.modifierFlags.intersection([.command, .control, .option]).isEmpty)?.rawValue : nil
        record("input-"+category, controller: controller, details: [
            "inputType": event.type.rawValue, "commandReady": ready,
            "commandAllowed": decoded != nil && (ready || decoded == "cancel"),
            "decodedCommand": decoded ?? "none",
            "inputModifiers": event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue,
            "inputWindow": event.windowNumber,
            "inputSourcePID": event.cgEvent?.getIntegerValueField(.eventSourceUnixProcessID) ?? -1,
            "inputTargetPID": event.cgEvent?.getIntegerValueField(.eventTargetUnixProcessID) ?? -1
        ])
    }
}

final class DrawingController: NSObject, NSWindowDelegate {
    enum EndReason: String { case escape, shortcut, focusLost, spaceChanged, screenChanged, submitted, settings, failure, terminate }
    private(set) var lifecycle = CaptureLifecycle()
    private(set) var window: NSWindow?
    private(set) var screen: NSScreen?
    let pad = Pad(frame: .zero)
    let cursor = DrawingCursor()
    let keyboard = DrawingKeyboard()
    let diagnostics = CaptureDiagnostics()
    var onSubmit: (() -> Void)?
    var onSessionEnd: (() -> Void)?
    var onError: ((String) -> Void)?
    var open: Bool { lifecycle.isOpen }
    private var prompt = OverlayLabel(labelWithString: "Draw your symbol")
    private var hints = OverlayLabel(labelWithString: "Enter – submit, C – clear, Esc – close")
    private var timer: Timer?
    private var cursorRecovery: Timer?
    private var deadline = Date.distantPast
    private var beganAt = Double.infinity
    private var previousApplication: NSRunningApplication?
    private var hiddenWindows: [NSWindow] = []
    private weak var recordingParent: NSWindow?
    private var recordingBackdrop: NSView?
    private var restoreWindows = false
    private var size = NSSize(width: 400, height: 250)
    private var corner = 0
    private var title = "Draw your symbol"
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else{return}
            if self.lifecycle.phase == .idle{self.releaseCursor(restorePosition:false)}
            self.tryReady()
            // Activation may select an arrow after the key-window readiness callback.
            self.cursor.refreshAppearance()
            self.diagnostics.record("app-active",controller:self)
        })
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in guard let self else{return};self.diagnostics.record("app-inactive",controller:self);self.lostFocus() })
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.end(.screenChanged) })
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let parent=self.recordingParent, note.object as? NSWindow === parent else{return}
            self.end(.focusLost)
        })
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.diagnostics.record("space-change", controller: self)
            guard self.open else{return}
            self.end(.spaceChanged)
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.end(.focusLost) })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.end(.focusLost) })
        pad.submitAction = { [weak self] in self?.handle(.submit) }
        pad.clearAction = { [weak self] in self?.handle(.clear) }
        pad.closeAction = { [weak self] in self?.handle(.cancel) }
        pad.drawingChanged = { [weak self] drawing in
            guard let self else { return }
            self.prompt.alphaValue = drawing ? 0 : 1
            self.diagnostics.record(drawing ? "stroke-start" : "cleared", controller: self)
        }
        pad.deviceChanged = { [weak self] device in self?.cacheDeviceSize(device) }
    }
    func present(corner: Int, title: String, contactsDown: Bool, device: UInt64? = nil, above parent: NSWindow? = nil) {
        guard let token = lifecycle.begin() else { return }
        beganAt=ProcessInfo.processInfo.systemUptime
        self.corner = max(0, min(3, corner)); self.title = title
        // Capture the display BEFORE any application activation or pointer warp.
        screen = parent?.screen ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { end(.failure); return }
        guard parent == nil || (parent!.isVisible && parent!.isOnActiveSpace) else{end(.failure);return}
        recordingParent=parent
        previousApplication = NSWorkspace.shared.frontmostApplication
        restoreWindows = previousApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        let visibleWindows=NSApp.windows.filter { $0.isVisible && $0.level == .normal }
        // Only restore windows that were on this Space. Off-Space Settings must remain out.
        hiddenWindows=parent == nil ? visibleWindows.filter { $0.isOnActiveSpace }:[]
        if parent == nil {visibleWindows.forEach { $0.orderOut(nil) }}
        let frame = parent.map {recordingOverlayFrame(size:size,parent:$0.frame,visible:screen.visibleFrame)}
            ?? overlayFrame(size:size,visible:screen.visibleFrame,corner:self.corner)
        let drawing = DrawingWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window = drawing; drawing.title = "Draw a gesture"; drawing.delegate = self
        drawing.isFloatingPanel=true;drawing.hidesOnDeactivate=false;drawing.becomesKeyOnlyIfNeeded=false;drawing.worksWhenModal=true
        drawing.isReleasedWhenClosed = false; drawing.isOpaque = false; drawing.backgroundColor = .clear
        drawing.isMovable = false; drawing.isMovableByWindowBackground = false; drawing.hasShadow = true
        drawing.level = .floating
        drawing.animationBehavior = .none
        drawing.collectionBehavior = parent == nil ? OverlayPlacementPolicy.arriving:OverlayPlacementPolicy.settled
        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: content.bounds); glass.style = .regular; glass.cornerRadius = 24; glass.contentView = content; drawing.contentView = glass
        } else {
            let effect = NSVisualEffectView(frame: content.bounds); effect.material = .hudWindow; effect.blendingMode = .behindWindow; effect.state = .active
            effect.wantsLayer = true; effect.layer?.cornerRadius = 24; effect.layer?.masksToBounds = true; effect.addSubview(content); drawing.contentView = effect
        }
        pad.frame = content.bounds; pad.capturing = false; pad.clear(); pad.rawAwaitLift = contactsDown;pad.rawDevice=device
        content.addSubview(pad)
        prompt.font = .systemFont(ofSize: 25, weight: .medium); prompt.textColor = .labelColor.withAlphaComponent(0.4); prompt.alignment = .center
        prompt.frame = NSRect(x: 24, y: frame.height/2-18, width: frame.width-48, height: 36); content.addSubview(prompt)
        hints.font = .systemFont(ofSize: 11); hints.textColor = .white.withAlphaComponent(0.85); hints.alignment = .center
        hints.frame = NSRect(x: 24, y: frame.height-54, width: frame.width-48, height: 34); content.addSubview(hints)
        if diagnostics.allowsQAControl {
            let drift = NSButton(title: "QA: change responder", target: self, action: #selector(exerciseResponderChangeForQA))
            drift.bezelStyle = .rounded; drift.frame = NSRect(x: 12, y: 12, width: 170, height: 28)
            drift.setAccessibilityLabel("QA change drawing responder"); content.addSubview(drift)
        }
        updateTitle(title)
        drawing.command = { [weak self] command in self?.handle(command) }
        drawing.maintainCursor = { [weak self] in self?.cursor.refreshAppearance() }
        drawing.alphaValue = 0
        if let parent, let root=parent.contentView {
            let backdrop=NSView(frame:root.bounds);backdrop.autoresizingMask=[.width,.height]
            backdrop.wantsLayer=true;backdrop.layer?.backgroundColor=NSColor.black.withAlphaComponent(0.52).cgColor
            backdrop.alphaValue=0;root.addSubview(backdrop);recordingBackdrop=backdrop
            parent.addChildWindow(drawing,ordered:.above)
        }
        deadline = Date().addingTimeInterval(1.5)
        diagnostics.record("present", controller: self)
        drawing.makeKeyAndOrderFront(nil); drawing.makeFirstResponder(pad)
        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.lifecycle.owns(token) else { return }
            if self.lifecycle.phase == .preparing { self.tryReady() }
            else {
                guard self.readyForCommands, let window = self.window else {
                    self.diagnostics.record("focus-contract-lost", controller: self)
                    self.end(self.window?.isOnActiveSpace == false ? .spaceChanged : .focusLost)
                    return
                }
                // Repair only this already-active key window. Never activate, move,
                // or make a window key while recovering responder ownership.
                if window.firstResponder !== self.pad {
                    let restored = window.makeFirstResponder(self.pad)
                    guard self.lifecycle.owns(token) else { return }
                    self.diagnostics.record(restored ? "responder-restored" : "responder-restore-failed", controller: self)
                    if !restored { self.end(.focusLost); return }
                }
                guard self.keyboard.systemCommandsEnabled else {
                    self.diagnostics.record("command-tap-unavailable", controller: self)
                    self.end(.failure); self.onError?("Drawing stopped because keyboard access was interrupted."); return
                }
                self.cursor.refreshAppearance()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        // AppKit activation is asynchronous. Do not take the cursor until didBecomeActive + key + responder are confirmed.
        NSApp.activate(ignoringOtherApps: true)
        tryReady()
    }
    private func tryReady() {
        guard let token = lifecycle.token, lifecycle.phase == .preparing, let window else { return }
        guard Date() < deadline else { diagnostics.record("focus-timeout", controller:self);onError?("Could not focus drawing mode. Please try again."); end(.failure); return }
        guard NSApp.isActive,NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else { return }
        if !window.isKeyWindow { window.makeKey() }
        if window.firstResponder !== pad { window.makeFirstResponder(pad) }
        guard lifecycle.owns(token), lifecycle.phase == .preparing, NSApp.isActive, !NSApp.isHidden, window.isVisible,
              window.isKeyWindow, window.firstResponder === pad, window.isOnActiveSpace else { return }
        // Pin the already-placed window before showing it. All-Spaces windows flash on
        // the destination before activeSpaceDidChange arrives; a single-Space window cannot.
        window.collectionBehavior = OverlayPlacementPolicy.settled
        guard lifecycle.owns(token),window.isOnActiveSpace else{return}
        if cursor.ownsResources{guard cursor.release(restorePosition:false) else{end(.failure);return}}
        cursorRecovery?.invalidate();cursorRecovery=nil
        guard keyboard.start(isReady: { [weak self] in
            guard let self else { return false }
            return self.lifecycle.owns(token) && self.readyForCommands
        }, received: { [weak self] event, ready in
            guard let self else { return }
            self.diagnostics.received(event, ready: ready, controller: self)
        }, systemCommand: { [weak self] command in
            guard let self else { return }
            self.diagnostics.record("key-system-"+command.rawValue, controller: self)
            self.handle(command)
            self.cursor.refreshAppearance()
        }, unavailable: { [weak self] in
            guard let self, self.lifecycle.owns(token) else { return }
            self.diagnostics.record("command-tap-disabled", controller: self)
            self.end(.failure); self.onError?("Drawing stopped because keyboard access was interrupted.")
        }, command: { [weak self] command in
            guard let self else { return }
            self.diagnostics.record("key-local-"+command.rawValue, controller: self)
            self.handle(command)
            self.cursor.refreshAppearance()
        }) else {
            end(.failure)
            onError?(AXIsProcessTrusted() ? "Drawing keyboard access is unavailable. Close password fields and try again." : "Allow LeviOsa in General → Accessibility to use drawing commands."); return
        }
        guard cursor.acquire(window: window, pad: pad) else { onError?("Could not lock the pointer for drawing."); end(.failure); return }
        guard lifecycle.ready(token, applicationActive: NSApp.isActive, keyWindow: window.isKeyWindow, padFocused: window.firstResponder === pad, onActiveSpace: window.isOnActiveSpace) else { end(.failure); return }
        pad.capturing = true
        diagnostics.record("ready", controller: self)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            self.recordingBackdrop?.animator().alphaValue = 1
        }
    }
    private func lostFocus() {
        guard lifecycle.phase == .drawing else { return }
        end(.focusLost)
    }
    func windowDidBecomeKey(_ notification: Notification) { tryReady() }
    func windowDidResignKey(_ notification: Notification) { lostFocus() }
    func windowWillClose(_ notification: Notification) { end(.focusLost) }
    private var readyForCommands: Bool {
        guard lifecycle.phase == .drawing, let window else { return false }
        // Commands belong to the capture window, independently of the current
        // first responder. Raw drawing also continues independently of that view.
        return NSApp.isActive && !NSApp.isHidden && window.isVisible && window.isKeyWindow && window.isOnActiveSpace
            && NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }
    private func handle(_ command: DrawingCommand) {
        if command == .cancel, lifecycle.isOpen {
            diagnostics.record("key-cancel", controller: self)
            end(.escape); return
        }
        guard readyForCommands else { return }
        diagnostics.record("key-"+command.rawValue, controller: self)
        switch command {
        case .submit: onSubmit?()
        case .clear: pad.clear(); updateTitle(title)
        case .cancel: end(.escape)
        }
    }
    func updateTitle(_ title: String) { self.title = title; prompt.stringValue = title;prompt.font = .systemFont(ofSize:25,weight:.medium);prompt.alphaValue = pad.points.isEmpty ? 1 : 0;hints.stringValue="Enter – submit, C – clear, Esc – close" }
    func waitForLift(){hints.stringValue="Lift your finger, then Enter – submit, Esc – close"}
    func reject(_ text: String) { pad.clear(); prompt.stringValue=text;prompt.font = .systemFont(ofSize:20,weight:.medium); diagnostics.record("rejected", controller: self) }
    func rawTouch(device: UInt64, count: Int, id: Int, x: Double, y: Double, receivedAt: Double) {
        guard lifecycle.phase == .drawing, receivedAt >= beganAt else { return }
        cursor.refreshAppearance()
        pad.rawTouch(device: device, count: count, id: id, x: x, y: y)
    }
    // Opt-in failure injection for native QA, never enabled by a normal launch.
    func exerciseCursorAppearanceForQA() {
        guard diagnostics.directory != nil,lifecycle.phase == .drawing,
              NSApp.isActive,window?.isKeyWindow == true,window?.isOnActiveSpace == true else{return}
        NSCursor.arrow.set()
        diagnostics.record("qa-cursor-reset",controller:self)
        cursor.refreshAppearance()
        diagnostics.record("qa-cursor-repaired",controller:self)
        window?.resetCursorRects()
        diagnostics.record("qa-cursor-rects-rebuilt",controller:self)
    }
    /// Exercise a responder transition without changing activation, Space or window ownership.
    @objc func exerciseResponderChangeForQA() {
        guard diagnostics.allowsQAControl, lifecycle.phase == .drawing,
              NSApp.isActive, let window, window.isKeyWindow else { return }
        let changed = window.makeFirstResponder(nil)
        diagnostics.record("qa-responder-drift", controller: self, details: ["responderChangeSucceeded": changed])
    }
    /// Invalidates callbacks BEFORE touching windows, so delegate notifications cannot re-enter cleanup.
    func end(_ reason: EndReason) {
        keyboard.stop()
        guard lifecycle.end() else { if cursor.ownsResources { releaseCursor(restorePosition:false) }; return }
        timer?.invalidate(); timer = nil
        pad.capturing = false
        let old = window; window = nil; old?.delegate = nil; (old as? DrawingWindow)?.command = nil; (old as? DrawingWindow)?.maintainCursor = nil
        let parent=recordingParent;recordingParent=nil
        // Cancel any entrance fade and remove the surface before cursor/backend cleanup.
        NSAnimationContext.runAnimationGroup { context in
            context.duration=0;old?.animator().alphaValue=0
        }
        old?.alphaValue=0;old?.orderOut(nil)
        releaseCursor(restorePosition:reason == .escape || reason == .shortcut || reason == .submitted || reason == .failure)
        if let old{parent?.removeChildWindow(old)}
        recordingBackdrop?.removeFromSuperview();recordingBackdrop=nil
        old?.close()
        diagnostics.record("end-"+reason.rawValue, controller: self)
        pad.clear()
        onSessionEnd?()
        let restore = reason == .escape || reason == .shortcut || reason == .failure
        let yieldFocus = restore || reason == .spaceChanged || reason == .screenChanged
        if let parent {
            if (restore || reason == .submitted),NSApp.isActive,parent.isVisible,parent.isOnActiveSpace {parent.makeKeyAndOrderFront(nil)}
        }else if yieldFocus && NSApp.isActive {
            if restore && restoreWindows { hiddenWindows.forEach { $0.makeKeyAndOrderFront(nil) } }
            else { NSApp.hide(nil) }
        }
        hiddenWindows = []; previousApplication = nil; restoreWindows = false; screen = nil
    }
    private func releaseCursor(restorePosition: Bool) {
        cursorRecovery?.invalidate();cursorRecovery=nil
        guard !cursor.release(restorePosition:restorePosition) else{return}
        // An OS-rejected unlock/show must be retried while idle, not forgotten.
        let recovery=Timer(timeInterval:0.1,repeats:true) { [weak self] timer in
            guard let self else{timer.invalidate();return}
            guard self.lifecycle.phase == .idle else{return}
            if self.cursor.release(restorePosition:false){timer.invalidate();self.cursorRecovery=nil}
        }
        cursorRecovery=recovery;RunLoop.main.add(recovery,forMode:.common)
    }
    private func cacheDeviceSize(_ device: NSSize) {
        guard device.width > 0, device.height > 0, let screen else { return }
        let display = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let mm = display.map { CGDisplayScreenSize($0) } ?? .zero
        let pointsPerMM = mm.width > 0 ? screen.frame.width/mm.width : 72/25.4
        let proposed = NSSize(width: device.width/72*25.4*pointsPerMM, height: device.height/72*25.4*pointsPerMM)
        if proposed.width.isFinite && proposed.height.isFinite { size = proposed }
        // Freeze geometry during drawing: touch metadata only sizes the NEXT session.
    }
}
