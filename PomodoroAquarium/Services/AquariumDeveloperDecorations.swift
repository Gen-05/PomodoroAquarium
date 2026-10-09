import CoreGraphics
import SwiftData

/// 開発用の無償所持。通常の初期データ・Shop購入・ポイントとは分離する。
enum AquariumDeveloperDecorations {
    // TODO: Release前にdeveloper owned decorationsを削除し、装飾はショップ購入のみへ変更する。
    // 今後の装飾はkindのstable IDをこのリストへ追加する。Releaseでは常に空。
#if DEBUG
    static let developerOwnedDecorationIDs: [String] = [
        AquariumDecorationKind.seaweedA.rawValue,
        AquariumDecorationKind.seaweedB.rawValue,
        AquariumDecorationKind.seaweedC.rawValue,
        AquariumDecorationKind.smallRockA.rawValue,
        AquariumDecorationKind.smallRockB.rawValue,
        AquariumDecorationKind.smallRockC.rawValue,
        AquariumDecorationKind.mediumRockA.rawValue,
        AquariumDecorationKind.mediumRockB.rawValue,
        AquariumDecorationKind.mediumRockC.rawValue,
        AquariumDecorationKind.coralAPink.rawValue,
        AquariumDecorationKind.coralAOrange.rawValue,
        AquariumDecorationKind.coralAPurple.rawValue,
        AquariumDecorationKind.coralBPink.rawValue,
        AquariumDecorationKind.coralBOrange.rawValue,
        AquariumDecorationKind.coralBPurple.rawValue,
        AquariumDecorationKind.coralCPink.rawValue,
        AquariumDecorationKind.coralCOrange.rawValue,
        AquariumDecorationKind.coralCPurple.rawValue
    ]
    static let ownedCountPerDecoration = 5
#else
    static let developerOwnedDecorationIDs: [String] = []
    static let ownedCountPerDecoration = 0
#endif

    @discardableResult
    static func seedIfNeeded(in context: ModelContext, enabled: Bool = true) throws -> Bool {
        guard enabled, !developerOwnedDecorationIDs.isEmpty else { return false }
        var existingIDs = Set(try context.fetch(
            FetchDescriptor<AquariumDecorationPlacement>()
        ).map(\.decorationID))
        var didInsert = false
        for id in developerOwnedDecorationIDs {
            guard let kind = AquariumDecorationKind(rawValue: id) else { continue }
            let position = kind.restorationPosition
            for index in 0..<ownedCountPerDecoration {
                // 1個目は以前のIDを維持。配置済みの個体を上書きせず、不足分だけ補充する。
                let placementID = index == 0
                    ? "developer-owned-\(id)"
                    : "developer-owned-\(id)-\(index + 1)"
                guard !existingIDs.contains(placementID) else { continue }
                context.insert(AquariumDecorationPlacement(
                    decorationID: placementID,
                    kind: kind,
                    relativeX: Double(position.x),
                    relativeY: Double(position.y),
                    scale: 1,
                    isPlaced: false
                ))
                existingIDs.insert(placementID)
                didInsert = true
            }
        }
        if didInsert { try context.save() }
        return didInsert
    }
}
