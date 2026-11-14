// SPDX-License-Identifier: MIT
import Foundation

/// Delayed work belongs to one session. Ending it invalidates all focus/animation callbacks.
struct CaptureLifecycle {
    enum Phase: String { case idle, preparing, drawing }
    private(set) var phase: Phase = .idle
    private(set) var token: UUID?
    var isOpen: Bool { phase != .idle }
    mutating func begin() -> UUID? {
        guard !isOpen else { return nil }
        let id = UUID(); token = id; phase = .preparing; return id
    }
    func owns(_ id: UUID) -> Bool { token == id && isOpen }
    mutating func ready(_ id: UUID, applicationActive: Bool, keyWindow: Bool, padFocused: Bool, onActiveSpace: Bool) -> Bool {
        guard owns(id), phase == .preparing, applicationActive, keyWindow, padFocused, onActiveSpace else { return false }
        phase = .drawing; return true
    }
    @discardableResult mutating func end() -> Bool {
        guard isOpen else { return false }
        phase = .idle; token = nil; return true
    }
}

enum DrawingCommand: String {
    case submit, clear, cancel
    static func decode(keyCode: UInt16, characters: String?, modified: Bool) -> DrawingCommand? {
        guard !modified else { return nil }
        switch keyCode {
        case 36, 76: return .submit
        case 53: return .cancel
        default: return characters?.lowercased() == "c" ? .clear : nil
        }
    }
}
