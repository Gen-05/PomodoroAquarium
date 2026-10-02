import SwiftData
import SwiftUI

struct RewardHistoryRow: View {
    let history: RewardHistorySnapshot
    var showsAcknowledgementStatus = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(history.rarity.rewardColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(history.fishName) ・ \(history.rarity.rawValue)")
                    .foregroundStyle(.primary)
                Text(history.acquiredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("+\(history.pointDelta)pt")
                    .font(.caption.monospacedDigit())

                if showsAcknowledgementStatus {
                    Label(
                        history.isAcknowledged ? "確認済み" : "未確認",
                        systemImage: history.isAcknowledged
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(history.isAcknowledged ? Color.secondary : Color.orange)
                }
            }
        }
    }
}

struct AcquisitionHistoryView: View {
    @Query(sort: \RewardHistoryEntry.acquiredAt, order: .reverse)
    private var entries: [RewardHistoryEntry]

    @MainActor
    private var recentHistory: [RewardHistorySnapshot] {
        entries.prefix(RewardHistoryService.maximumEntryCount)
            .map(RewardHistorySnapshot.init(entry:))
    }

    var body: some View {
        List {
            if recentHistory.isEmpty {
                ContentUnavailableView(
                    "まだ獲得履歴はありません",
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity, minHeight: 280)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(recentHistory) { history in
                    RewardHistoryRow(history: history)
                        .accessibilityIdentifier("acquisitionHistory.row.\(history.id.uuidString)")
                }
            }
        }
        .navigationTitle("獲得履歴")
    }
}

#Preview {
    NavigationStack {
        AcquisitionHistoryView()
    }
    .modelContainer(for: RewardHistoryEntry.self, inMemory: true)
}
