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

enum FocusMethod: String, Codable, CaseIterable, Identifiable {
    case pomodoro
    case timer
    case stopwatch
    case legacy

    var id: Self { self }

    var displayName: String {
        switch self {
        case .pomodoro: "ポモドーロ"
        case .timer: "タイマー"
        case .stopwatch: "ストップウォッチ"
        case .legacy: "ポモドーロ"
        }
    }
}

/// 日別集計とは別に、将来のカテゴリ・集中方法別集計へ使う完了セッション明細。
@Model
final class FocusSessionRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    /// 実際の初回study開始日時。旧履歴は不明な開始日を推測せず完了日時へfallback。
    var sessionStartedAt: Date?
    var durationMinutes: Int
    /// 新しい記録は正確な秒数を保持する。旧履歴はdurationMinutes * 60へfallback。
    var durationSeconds: Int?
    /// nilは魚進捗へ未処理。0も処理済みであり、session IDと共に二重加算を防ぐ。
    var fishEarnedCount: Int?
    /// nilは新ポイント方式へ未処理。0も処理済み。coinsと同じsaveで確定する。
    var pointReward: Int?
    /// 通常レートへ割り当てた有効秒数。残りは低レート。日次端数の復元根拠。
    var normalPointSeconds: Int?
    /// sessionの即時claim判定済み印。未受取権は日次カウンターに残し、演出とは独立。
    var hasGrantedFishReward = false
    /// Optionalにして、カテゴリを持たない旧履歴を「勉強」へfallbackできるようにする。
    var categoryID: String?
    /// Optionalのまま追加し、保存値を持たない旧履歴を推測せずlegacyとして扱う。
    var focusMethodRawValue: String?

    init(
        id: UUID = UUID(),
        completedAt: Date,
        durationMinutes: Int,
        categoryID: String? = FocusCategoryDefaults.studyID,
        focusMethod: FocusMethod? = nil,
        durationSeconds: Int? = nil,
        sessionStartedAt: Date? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.sessionStartedAt = sessionStartedAt
        self.durationMinutes = max(0, durationMinutes)
        self.durationSeconds = durationSeconds.map { max(0, $0) }
        self.categoryID = categoryID
        focusMethodRawValue = focusMethod?.rawValue
    }

    var resolvedCategoryID: String {
        FocusCategoryDefaults.resolvedCategoryID(categoryID)
    }

    var attributionDate: Date { sessionStartedAt ?? completedAt }

    func sessionDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: attributionDate)
    }

    var validFocusSeconds: Int {
        if let durationSeconds { return max(0, durationSeconds) }
        let (seconds, overflowed) = max(0, durationMinutes).multipliedReportingOverflow(by: 60)
        return overflowed ? Int.max : seconds
    }

    var focusMethod: FocusMethod {
        FocusMethod(rawValue: focusMethodRawValue ?? "") ?? .legacy
    }
}

enum FocusSessionHistoryMigration {
    struct FocusMethodMigrationResult: Equatable {
        let legacyRecordCount: Int
        let migratedRecordCount: Int
        let migratedMinutes: Int
        let totalMinutesBefore: Int
        let totalMinutesAfter: Int
    }

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
                    categoryID: FocusCategoryDefaults.studyID,
                    focusMethod: .pomodoro
                ))
            }
            record.categoryHistoryMigratedAt = migratedAt
        }
        try context.save()
    }

    /// 未リリース期間に作成された集中方法未設定の履歴を、既知のPomodoro履歴へ変換する。
    /// record自体は維持し、集中方法フィールドだけを更新するため、複数回呼んでも安全。
    @discardableResult
    @MainActor
    static func migrateLegacyFocusMethodsToPomodoroIfNeeded(
        in context: ModelContext
    ) throws -> FocusMethodMigrationResult {
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>())
        let totalMinutesBefore = records.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let legacyRecords = records.filter { $0.focusMethod == .legacy }
        let migratedMinutes = legacyRecords.reduce(0) { $0 + max(0, $1.durationMinutes) }

        for record in legacyRecords {
            record.focusMethodRawValue = FocusMethod.pomodoro.rawValue
        }
        if !legacyRecords.isEmpty {
            try context.save()
        }

        let totalMinutesAfter = records.reduce(0) { $0 + max(0, $1.durationMinutes) }
        return FocusMethodMigrationResult(
            legacyRecordCount: legacyRecords.count,
            migratedRecordCount: legacyRecords.count,
            migratedMinutes: migratedMinutes,
            totalMinutesBefore: totalMinutesBefore,
            totalMinutesAfter: totalMinutesAfter
        )
    }
}
