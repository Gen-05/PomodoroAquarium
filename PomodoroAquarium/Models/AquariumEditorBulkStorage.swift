import Foundation

/// A value-only edit. One result can be recorded as one existing history operation.
enum AquariumEditorBulkStorage: String, Identifiable {
    case fish, decorations
    var id: String { rawValue }

    func applying(to draft: AquariumEditorDraft) -> AquariumEditorDraft? {
        var result = draft.snapshot
        switch self {
        case .fish:
            guard !result.fishIDs.isEmpty else { return nil }
            result.fishIDs.removeAll()
        case .decorations:
            guard result.placements.contains(where: { $0.isPlaced }) else { return nil }
            for index in result.placements.indices { result.placements[index].isPlaced = false }
        }
        return result
    }
}
