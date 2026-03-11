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
                    rateLimitsSection
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
        .frame(width: 300)
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

}
