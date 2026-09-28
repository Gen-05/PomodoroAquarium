import Foundation
import SwiftData

enum FocusCategoryColorKey: String, Codable, CaseIterable {
    case studyBlue
    case readingCoral
    case qualificationPurple
    case testAmber
    case assignmentMint
    case languagePink
    case oceanTeal
    case skyIndigo
    case sunsetOrange
    case aquaCyan
}

enum FocusCategoryDefaults {
    static let studyID = "focus-category.study"
    static let readingID = "focus-category.reading"
    static let qualificationID = "focus-category.qualification"
    static let testStudyID = "focus-category.test-study"
    static let assignmentID = "focus-category.assignment"
    static let languageID = "focus-category.language"

    static func resolvedCategoryID(_ categoryID: String?) -> String {
        guard let categoryID, !categoryID.isEmpty else { return studyID }
        return categoryID
    }
}

enum FocusCategoryHexColor {
    static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard digits.count == 6 else { return nil }

        let validScalars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard digits.unicodeScalars.allSatisfy(validScalars.contains) else { return nil }
        return "#\(digits.uppercased())"
    }
}

@Model
final class FocusCategory {
    @Attribute(.unique) var id: String
    var name: String
    /// SwiftUI.Colorではなく、グラフ等でも再利用できる固定色キーを永続化する。
    var color: String
    /// 自作カテゴリの自由色。既存カテゴリとの互換性のためoptionalで保持する。
    var customHex: String?
    var isDefault: Bool
    /// 過去の集中記録から参照できるよう、削除時もモデルは残して選択候補だけから外す。
    var isArchived: Bool = false

    init(
        id: String,
        name: String,
        color: FocusCategoryColorKey,
        customHex: String? = nil,
        isDefault: Bool,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color.rawValue
        self.customHex = FocusCategoryHexColor.normalized(customHex)
        self.isDefault = isDefault
        self.isArchived = isArchived
    }

    var colorKey: FocusCategoryColorKey {
        FocusCategoryColorKey(rawValue: color) ?? .studyBlue
    }

    var resolvedCustomHex: String? {
        FocusCategoryHexColor.normalized(customHex)
    }
}

enum FocusCategoryService {
    static let maximumNameLength = 20

    enum CreationError: LocalizedError, Equatable {
        case emptyName
        case nameTooLong
        case duplicateName
        case invalidColor

        var errorDescription: String? {
            switch self {
            case .emptyName:
                "カテゴリ名を入力してください"
            case .nameTooLong:
                "カテゴリ名は\(FocusCategoryService.maximumNameLength)文字以内で入力してください"
            case .duplicateName:
                "同じ名前のカテゴリがあります"
            case .invalidColor:
                "選択した色を保存できません"
            }
        }
    }

    enum ArchiveError: LocalizedError, Equatable {
        case defaultCategory

        var errorDescription: String? {
            switch self {
            case .defaultCategory:
                "初期カテゴリは削除できません"
            }
        }
    }

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
        ),
        DefaultDefinition(
            id: FocusCategoryDefaults.qualificationID,
            name: "資格勉強",
            color: .qualificationPurple
        ),
        DefaultDefinition(
            id: FocusCategoryDefaults.testStudyID,
            name: "テスト勉強",
            color: .testAmber
        ),
        DefaultDefinition(
            id: FocusCategoryDefaults.assignmentID,
            name: "課題",
            color: .assignmentMint
        ),
        DefaultDefinition(
            id: FocusCategoryDefaults.languageID,
            name: "語学",
            color: .languagePink
        )
    ]

    /// IDと正規化した名前を基準に不足分だけを作るため、既存カテゴリを壊さず重複しない。
    @discardableResult
    @MainActor
    static func createDefaultsIfNeeded(in context: ModelContext) throws -> [FocusCategory] {
        let existing = try context.fetch(FetchDescriptor<FocusCategory>())
        let existingIDs = Set(existing.map(\.id))
        let existingNames = Set(existing.map { normalizedNameKey($0.name) })
        var didInsert = false

        for definition in defaultDefinitions
        where !existingIDs.contains(definition.id) &&
            !existingNames.contains(normalizedNameKey(definition.name)) {
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

    @discardableResult
    @MainActor
    static func createCustom(
        name rawName: String,
        color: FocusCategoryColorKey,
        in context: ModelContext
    ) throws -> FocusCategory {
        try createCustom(
            name: rawName,
            fallbackColor: color,
            customHex: nil,
            in: context
        )
    }

    @discardableResult
    @MainActor
    static func createCustom(
        name rawName: String,
        customHex: String,
        in context: ModelContext
    ) throws -> FocusCategory {
        guard let normalizedHex = FocusCategoryHexColor.normalized(customHex) else {
            throw CreationError.invalidColor
        }
        return try createCustom(
            name: rawName,
            fallbackColor: .oceanTeal,
            customHex: normalizedHex,
            in: context
        )
    }

    @MainActor
    private static func createCustom(
        name rawName: String,
        fallbackColor: FocusCategoryColorKey,
        customHex: String?,
        in context: ModelContext
    ) throws -> FocusCategory {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CreationError.emptyName }
        guard name.count <= maximumNameLength else { throw CreationError.nameTooLong }

        let nameKey = normalizedNameKey(name)
        let existing = try context.fetch(FetchDescriptor<FocusCategory>())
        let sameNameCategories = existing.filter {
            normalizedNameKey($0.name) == nameKey
        }
        guard !sameNameCategories.contains(where: { !$0.isArchived }) else {
            throw CreationError.duplicateName
        }

        if let archivedCategory = sameNameCategories.first(where: {
            $0.isArchived && !$0.isDefault
        }) {
            archivedCategory.name = name
            archivedCategory.color = fallbackColor.rawValue
            archivedCategory.customHex = FocusCategoryHexColor.normalized(customHex)
            archivedCategory.isArchived = false
            try context.save()
            return archivedCategory
        }

        guard sameNameCategories.isEmpty else {
            throw CreationError.duplicateName
        }

        let category = FocusCategory(
            id: "focus-category.custom.\(UUID().uuidString.lowercased())",
            name: name,
            color: fallbackColor,
            customHex: customHex,
            isDefault: false
        )
        context.insert(category)
        try context.save()
        return category
    }

    @MainActor
    static func archive(
        _ category: FocusCategory,
        in context: ModelContext
    ) throws {
        guard !category.isDefault else { throw ArchiveError.defaultCategory }
        guard !category.isArchived else { return }
        category.isArchived = true
        try context.save()
    }

    static func activeOrdered(_ categories: [FocusCategory]) -> [FocusCategory] {
        ordered(categories.filter { !$0.isArchived })
    }

    static func resolvedSelectionID(
        _ selectedCategoryID: String,
        from categories: [FocusCategory]
    ) -> String {
        categories.contains {
            $0.id == selectedCategoryID && !$0.isArchived
        } ? selectedCategoryID : FocusCategoryDefaults.studyID
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

    private static func normalizedNameKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
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
