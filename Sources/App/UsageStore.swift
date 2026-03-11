import Foundation
import SwiftUI

@Observable
final class UsageStore {
    var stats: StatsCache?
    var oauthUsage: OAuthUsage?
    var lastRefresh: Date?
    var error: String?
    var isLoading = false

    private var timer: Timer?
    private let statsPath: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path()
        self.statsPath = "\(home)/.claude/stats-cache.json"
        refresh()
        startAutoRefresh()
    }

    func refresh() {
        loadLocalStats()
        Task { await fetchOAuthUsage() }
    }

    // MARK: - Local Stats

    private func loadLocalStats() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: statsPath))
            stats = try JSONDecoder().decode(StatsCache.self, from: data)
        } catch {
            self.error = "Stats: \(error.localizedDescription)"
        }
    }

    // MARK: - OAuth Usage API

    @MainActor
    func fetchOAuthUsage() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = getOAuthToken() else {
            self.error = "No OAuth token found in Keychain"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ClaudeUsageBar/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            oauthUsage = try JSONDecoder().decode(OAuthUsage.self, from: data)
            lastRefresh = Date()
            error = nil
        } catch {
            self.error = "API: \(error.localizedDescription)"
        }
    }

    private func getOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Computed Properties

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var todayActivity: DailyActivity? {
        stats?.dailyActivity.first { $0.date == todayKey }
    }

    var thisWeekActivities: [DailyActivity] {
        guard let activities = stats?.dailyActivity else { return [] }
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return []
        }
        return activities.filter { a in
            guard let d = a.localDate else { return false }
            return d >= weekStart && d <= now
        }
    }

    var weekMessages: Int { thisWeekActivities.reduce(0) { $0 + $1.messageCount } }
    var weekSessions: Int { thisWeekActivities.reduce(0) { $0 + $1.sessionCount } }

    var recentDays: [DailyActivity] {
        Array((stats?.dailyActivity ?? []).suffix(14))
    }

    var sortedModelUsage: [(name: String, usage: ModelUsage)] {
        guard let usage = stats?.modelUsage else { return [] }
        return usage.sorted { $0.value.outputTokens > $1.value.outputTokens }
            .map { (name: shortModelName($0.key), usage: $0.value) }
    }

    func shortModelName(_ full: String) -> String {
        let map: [String: String] = [
            "claude-opus-4-6": "Opus 4.6",
            "claude-opus-4-5-20251101": "Opus 4.5",
            "claude-sonnet-4-6": "Sonnet 4.6",
            "claude-sonnet-4-5-20250929": "Sonnet 4.5",
            "claude-haiku-4-5-20251001": "Haiku 4.5",
        ]
        return map[full] ?? full
    }

    // MARK: - Menu bar label

    var menuBarLabel: String {
        guard let fiveH = oauthUsage?.fiveHour else { return "--" }
        return "\(Int(fiveH.utilization))% \(fiveH.timeUntilReset)"
    }
}
