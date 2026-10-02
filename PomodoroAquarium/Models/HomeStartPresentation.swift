import Foundation

enum HomeDailyMessage {
    static let messages = [
        "今日も、できるところから。",
        "焦らず、自分のペースで。",
        "まずはひとつ、始めてみよう。",
        "魚たちと一緒に、少しずつ。",
        "深く潜るように、ひとつのことへ。",
        "今日の一歩を、水族館に残そう。",
        "ひと息ついて、目の前のことから。",
        "小さな集中を、今日の水槽に。",
        "ゆっくりでも、続いた時間は残る。",
        "今できることを、ひとつだけ。",
        "静かな時間を、魚たちと。",
        "少しだけ、ひとつのことに潜ってみよう。",
        "今日は今日のペースで。",
        "ここから、ひと区切り。",
        "目の前の一歩から、ゆっくりと。",
        "いつもの水槽で、新しいひと区切り。",
        "今日の少しが、明日につながる。",
        "水槽を眺めて、気持ちを整えて。",
        "魚たちも、そっと見守っている。",
        "ひとつずつ、ゆっくり進もう。",
        "静かな水面のように、落ち着いて。",
        "できる分だけ、積み重ねよう。",
        "ひと区切りの時間を、自分に。",
        "今日も、ここから。",
        "少しの時間を、大切なことへ。"
    ]

    static func message(on date: Date, calendar: Calendar = .current) -> String {
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let day = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: referenceDay, to: day).day ?? 0
        let index = (offset % messages.count + messages.count) % messages.count
        return messages[index]
    }
}

/// Guards only Home's short visual transition; it never starts a timer session.
struct HomeStartTransitionState {
    static let navigationDelay: TimeInterval = 0.28
    private(set) var isOpening = false
    private(set) var requestID: UUID?

    mutating func begin(isDestinationPresented: Bool) -> UUID? {
        guard !isOpening, !isDestinationPresented else { return nil }
        isOpening = true
        let id = UUID()
        requestID = id
        return id
    }

    mutating func consume(id: UUID) -> Bool {
        guard isOpening, requestID == id else { return false }
        requestID = nil
        return true
    }

    mutating func reset() {
        isOpening = false
        requestID = nil
    }
}
