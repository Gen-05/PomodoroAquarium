import Foundation
import SwiftData

@Model
final class StudyDailyRecord {
    @Attribute(.unique) var day: Date
    var studyMinutes: Int
    /// nilはカテゴリ機能追加前の履歴。初回移行後は日時を保持する。
    var categoryHistoryMigratedAt: Date?

    init(
        day: Date,
        studyMinutes: Int = 0,
        categoryHistoryMigratedAt: Date? = Date()
    ) {
        self.day = day
        self.studyMinutes = max(0, studyMinutes)
        self.categoryHistoryMigratedAt = categoryHistoryMigratedAt
    }
}

struct DailyStudySummary: Identifiable, Equatable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}

struct MonthlyStudyDay: Identifiable, Equatable {
    let id: Int
    let date: Date?
    let minutes: Int
}
