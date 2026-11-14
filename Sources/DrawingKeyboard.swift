// SPDX-License-Identifier: MIT
import AppKit

/// Owns upstream command capture and the local fallback for one drawing session.
/// Both are acquired before pointer locking and invalidated before any focus handoff.
final class DrawingKeyboard {
    typealias Handler = (NSEvent) -> NSEvent?
    typealias Installer = (@escaping Handler) -> Any?
    typealias TapFactory = (@escaping () -> Bool, @escaping (DrawingCommand) -> Void, @escaping () -> Void) -> DrawingCommandRegistration?
    private let makeTap: TapFactory
    private var tap: DrawingCommandRegistration?
    var systemCommandsEnabled: Bool { tap?.isEnabled == true }
    private let install: Installer
    private let remove: (Any) -> Void
    private var monitor: Any?
    private var generation: UUID?
    var isMonitoring: Bool { monitor != nil }

    init(install: @escaping Installer = { NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged], handler: $0) },
         remove: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) },
         makeTap: @escaping TapFactory = { DrawingCommandTap(ready: $0, command: $1, unavailable: $2) }) {
        self.install = install; self.remove = remove; self.makeTap = makeTap
    }

    @discardableResult
    func start(isReady: @escaping () -> Bool, received: ((NSEvent, Bool) -> Void)? = nil,
               systemCommand: ((DrawingCommand) -> Void)? = nil,
               unavailable: @escaping () -> Void = {}, command: @escaping (DrawingCommand) -> Void) -> Bool {
        stop()
        let token = UUID(); generation = token
        guard let registration = makeTap({ [weak self] in
            self?.generation == token && isReady()
        }, { [weak self] action in
            guard self?.generation == token, isReady() else { return }
            (systemCommand ?? command)(action)
        }, { [weak self] in
            guard self?.generation == token else { return }
            unavailable()
        }) else { stop(); return false }
        guard registration.isEnabled else { registration.invalidate(); generation = nil; return false }
        tap = registration
        guard let installed = install({ [weak self] event in
            guard let self, self.generation == token else { return event }
            let ready = isReady()
            received?(event, ready)
            guard event.type == .keyDown,
                  let action = DrawingCommand.decode(keyCode: event.keyCode,
                      characters: event.charactersIgnoringModifiers,
                      modified: !event.modifierFlags.intersection([.command, .control, .option]).isEmpty),
                  ready || action == .cancel
            else { return event }
            // This monitor belongs only to our current capture. Escape must release
            // it even if responder/focus readiness changed before cleanup ran.
            command(action)
            return nil
        }) else { stop(); return false }
        monitor = installed
        return true
    }

    func stop() {
        generation = nil
        let registration = tap; tap = nil; registration?.invalidate()
        let previous = monitor; monitor = nil
        if let previous { remove(previous) }
    }
    deinit { stop() }
}
