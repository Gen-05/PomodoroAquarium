import Foundation
import SwiftData

enum FocusCategoryColorKey: String, Codable, CaseIterable {
    case studyBlue
    case readingCoral
}

enum FocusCategoryDefaults {
    static let studyID = "focus-category.study"
    static let readingID = "focus-category.reading"

    static func resolvedCategoryID(_ categoryID: String?) -> String {
        guard let categoryID, !categoryID.isEmpty else { return studyID }
        return categoryID
    }
}

@Model
final class FocusCategory {
    @Attribute(.unique) var id: String
    var name: String
    /// SwiftUI.Colorではなく、グラフ等でも再利用できる固定色キーを永続化する。
    var color: String
    var isDefault: Bool

    init(
        id: String,
        name: String,
        color: FocusCategoryColorKey,
        isDefault: Bool
    ) {
        self.id = id
        self.name = name
        self.color = color.rawValue
        self.isDefault = isDefault
    }

    var colorKey: FocusCategoryColorKey {
        FocusCategoryColorKey(rawValue: color) ?? .studyBlue
    }
}

enum FocusCategoryService {
    struct DefaultDefinition: Equatable {
        let id: String
        let name: String
        let color: FocusCategoryColorKey
    }

    static let defaultDefinitions = [
        DefaultDefinition(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue
        ),
        DefaultDefinition(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral
        )
    ]

    /// IDを基準に不足分だけを作るため、複数回呼んでも重複しない。
    @discardableResult
    @MainActor
    static func createDefaultsIfNeeded(in context: ModelContext) throws -> [FocusCategory] {
        let existing = try context.fetch(FetchDescriptor<FocusCategory>())
        let existingIDs = Set(existing.map(\.id))
        var didInsert = false

        for definition in defaultDefinitions where !existingIDs.contains(definition.id) {
            context.insert(FocusCategory(
                id: definition.id,
                name: definition.name,
                color: definition.color,
                isDefault: true
            ))
            didInsert = true
        }

        if didInsert {
            try context.save()
        }

        return ordered(try context.fetch(FetchDescriptor<FocusCategory>()))
    }

    static func ordered(_ categories: [FocusCategory]) -> [FocusCategory] {
        let defaultOrder = Dictionary(
            uniqueKeysWithValues: defaultDefinitions.enumerated().map { ($1.id, $0) }
        )
        return categories.sorted { lhs, rhs in
            let lhsOrder = defaultOrder[lhs.id] ?? Int.max
            let rhsOrder = defaultOrder[rhs.id] ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

/// 日別集計とは別に、将来のカテゴリ別集計へ使う完了セッション明細。
@Model
final class FocusSessionRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var durationMinutes: Int
    /// Optionalにして、カテゴリを持たない旧履歴を「勉強」へfallbackできるようにする。
    var categoryID: String?

    init(
        id: UUID = UUID(),
        completedAt: Date,
        durationMinutes: Int,
        categoryID: String? = FocusCategoryDefaults.studyID
    ) {
        self.id = id
        self.completedAt = completedAt
        self.durationMinutes = max(0, durationMinutes)
        self.categoryID = categoryID
    }

    var resolvedCategoryID: String {
        FocusCategoryDefaults.resolvedCategoryID(categoryID)
    }
}

enum FocusSessionHistoryMigration {
    /// 旧日別履歴を「勉強」の1日分明細として一度だけ補完する。
    /// 以後の完了分はStudyHistoryServiceがセッション単位で追記する。
    @MainActor
    static func migrateLegacyDailyRecordsIfNeeded(in context: ModelContext) throws {
        let legacyRecords = try context.fetch(FetchDescriptor<StudyDailyRecord>())
            .filter { $0.categoryHistoryMigratedAt == nil }
        guard !legacyRecords.isEmpty else { return }

        let migratedAt = Date()
        for record in legacyRecords {
            if record.studyMinutes > 0 {
                context.insert(FocusSessionRecord(
                    completedAt: record.day,
                    durationMinutes: record.studyMinutes,
                    categoryID: FocusCategoryDefaults.studyID
                ))
            }
            record.categoryHistoryMigratedAt = migratedAt
        }
        try context.save()
    }
}
