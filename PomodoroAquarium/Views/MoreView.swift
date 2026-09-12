import SwiftUI

struct MoreView: View {
    var body: some View {
        List {
            NavigationLink {
                BookView()
            } label: {
                Label("図鑑", systemImage: "book.closed.fill")
            }
            .accessibilityIdentifier("more.book")

            NavigationLink {
                SettingsView()
            } label: {
                Label("設定", systemImage: "gearshape.fill")
            }
            .accessibilityIdentifier("more.settings")
        }
        .navigationTitle("その他")
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}
