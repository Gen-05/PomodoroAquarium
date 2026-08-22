import Foundation
import SwiftData

@Model
final class StudyDailyRecord {
    @Attribute(.unique) var day: Date
    var studyMinutes: Int

    init(day: Date, studyMinutes: Int = 0) {
        self.day = day
        self.studyMinutes = max(0, studyMinutes)
    }
}

struct DailyStudySummary: Identifiable, Equatable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}
