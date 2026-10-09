import Foundation

/// 31 snapshots represent up to 30 operations. Each snapshot has no nested history.
struct AquariumEditorHistory: Codable, Equatable {
    static let maximumOperations = 30
    private(set) var states: [AquariumEditorDraft]
    private(set) var position: Int
    var canUndo: Bool { position > 0 }
    var canRedo: Bool { position + 1 < states.count }
    var current: AquariumEditorDraft { states[position] }

    init(initial: AquariumEditorDraft) {
        states = [initial.snapshot]
        position = 0
    }
    func isValid(for draft: AquariumEditorDraft) -> Bool {
        !states.isEmpty && states.count <= Self.maximumOperations + 1 &&
        states.indices.contains(position) &&
        states.allSatisfy { $0.history == nil && $0.isValid } && current == draft.snapshot
    }
    @discardableResult
    mutating func record(_ draft: AquariumEditorDraft) -> Bool {
        let next = draft.snapshot
        guard current != next else { return false }
        states = Array(states.prefix(position + 1))
        states.append(next)
        if states.count > Self.maximumOperations + 1 { states.removeFirst() }
        position = states.count - 1
        return true
    }
    mutating func undo() -> AquariumEditorDraft? {
        guard canUndo else { return nil }
        position -= 1
        return current
    }
    mutating func redo() -> AquariumEditorDraft? {
        guard canRedo else { return nil }
        position += 1
        return current
    }
}
