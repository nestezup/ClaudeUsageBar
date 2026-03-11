import SwiftUI

@main
struct ClaudeUsageBarApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsageView(store: store)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkle")
                Text(store.menuBarLabel)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
