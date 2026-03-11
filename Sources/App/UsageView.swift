import SwiftUI

struct UsageView: View {
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Rate Limits Section
                    rateLimitsSection

                    Divider()

                    // Today's Activity
                    todaySection

                    Divider()

                    // Weekly Summary
                    weeklySection

                    Divider()

                    // Activity Chart
                    chartSection

                    Divider()

                    // Model Usage
                    modelSection
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                if let t = store.lastRefresh {
                    Text("Updated \(t.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    store.refresh()
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 520)
    }

    // MARK: - Rate Limits

    @ViewBuilder
    var rateLimitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rate Limits", systemImage: "gauge.with.needle")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if let usage = store.oauthUsage {
                if let fiveH = usage.fiveHour {
                    limitRow(
                        label: "5-Hour",
                        utilization: fiveH.utilization,
                        resetsIn: fiveH.timeUntilReset,
                        color: colorForUtilization(fiveH.utilization)
                    )
                }
                if let sevenD = usage.sevenDay {
                    limitRow(
                        label: "Weekly",
                        utilization: sevenD.utilization,
                        resetsIn: sevenD.timeUntilReset,
                        color: colorForUtilization(sevenD.utilization)
                    )
                }
                if let opus = usage.sevenDayOpus {
                    limitRow(
                        label: "Opus 7d",
                        utilization: opus.utilization,
                        resetsIn: opus.timeUntilReset,
                        color: colorForUtilization(opus.utilization)
                    )
                }
                if let sonnet = usage.sevenDaySonnet {
                    limitRow(
                        label: "Sonnet 7d",
                        utilization: sonnet.utilization,
                        resetsIn: sonnet.timeUntilReset,
                        color: colorForUtilization(sonnet.utilization)
                    )
                }
                if let extra = usage.extraUsage, extra.isEnabled {
                    HStack {
                        Text("Extra Credits")
                            .font(.caption)
                        Spacer()
                        Text("$\(String(format: "%.1f", extra.usedCredits ?? 0)) / $\(extra.monthlyLimit ?? 0)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let err = store.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func limitRow(label: String, utilization: Double, resetsIn: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(color)
                Text("resets \(resetsIn)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.gradient)
                        .frame(width: geo.size.width * min(utilization / 100, 1.0))
                }
            }
            .frame(height: 6)
        }
    }

    func colorForUtilization(_ u: Double) -> Color {
        if u >= 80 { return .red }
        if u >= 50 { return .orange }
        return .green
    }

    // MARK: - Today

    @ViewBuilder
    var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today", systemImage: "calendar")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            if let today = store.todayActivity {
                HStack(spacing: 16) {
                    statBadge(value: "\(today.messageCount)", label: "msgs", icon: "bubble.left.fill", color: .blue)
                    statBadge(value: "\(today.toolCallCount)", label: "tools", icon: "wrench.fill", color: .orange)
                    statBadge(value: "\(today.sessionCount)", label: "sessions", icon: "rectangle.stack.fill", color: .purple)
                }
            } else {
                Text("No activity yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.body, design: .rounded).bold())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly

    @ViewBuilder
    var weeklySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("This Week", systemImage: "chart.bar")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statBadge(value: "\(store.weekMessages)", label: "messages", icon: "bubble.left.fill", color: .blue)
                statBadge(value: "\(store.weekSessions)", label: "sessions", icon: "rectangle.stack.fill", color: .purple)
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recent Activity", systemImage: "chart.xyaxis.line")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            let days = store.recentDays
            if !days.isEmpty {
                let maxMsg = days.map(\.messageCount).max() ?? 1
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(days) { day in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.date == store.todayActivity?.date ? Color.purple : Color.blue.opacity(0.6))
                                .frame(height: max(2, CGFloat(day.messageCount) / CGFloat(maxMsg) * 60))
                            Text(String(day.date.suffix(2)))
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 75)
            }
        }
    }

    // MARK: - Model Usage

    @ViewBuilder
    var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("All-Time Models", systemImage: "cpu")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(store.sortedModelUsage, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                    Spacer()
                    Text(formatTokens(item.usage.outputTokens))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("out")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
