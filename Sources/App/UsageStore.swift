import Foundation
import SwiftUI

@Observable
final class UsageStore {
    var oauthUsage: OAuthUsage?
    var lastRefresh: Date?
    var error: String?
    var isLoading = false

    private var timer: Timer?

    init() {
        refresh()
        startAutoRefresh()
    }

    func refresh() {
        Task { await fetchOAuthUsage() }
    }

    // MARK: - OAuth Usage API

    @MainActor
    func fetchOAuthUsage() async {
        isLoading = true
        defer { isLoading = false }

        // 토큰 만료 확인 → 만료됐으면 먼저 갱신
        if isTokenExpired() {
            let refreshed = await refreshOAuthToken()
            if !refreshed {
                self.error = "Token expired, refresh failed"
                return
            }
        }

        guard let token = getOAuthToken() else {
            self.error = "No OAuth token found in Keychain"
            return
        }

        let result = await callUsageAPI(token: token)
        switch result {
        case .success(let data):
            oauthUsage = try? JSONDecoder().decode(OAuthUsage.self, from: data)
            lastRefresh = Date()
            error = nil
        case .unauthorized:
            // 401 → 토큰 갱신 후 재시도
            let refreshed = await refreshOAuthToken()
            if refreshed, let newToken = getOAuthToken() {
                let retry = await callUsageAPI(token: newToken)
                if case .success(let data) = retry {
                    oauthUsage = try? JSONDecoder().decode(OAuthUsage.self, from: data)
                    lastRefresh = Date()
                    error = nil
                } else {
                    self.error = "API failed after token refresh"
                }
            } else {
                self.error = "Token refresh failed"
            }
        case .rateLimited(let retryAfter):
            self.error = "Rate limited, retry in \(Int(retryAfter))s..."
            try? await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            if let token = getOAuthToken() {
                let retry = await callUsageAPI(token: token)
                if case .success(let data) = retry {
                    oauthUsage = try? JSONDecoder().decode(OAuthUsage.self, from: data)
                    lastRefresh = Date()
                    error = nil
                }
            }
        case .error(let msg):
            self.error = msg
        }
    }

    private enum APIResult {
        case success(Data)
        case unauthorized
        case rateLimited(Double)
        case error(String)
    }

    private func callUsageAPI(token: String) async -> APIResult {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            return .error("Invalid URL")
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("claude-code/2.1.72", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            if statusCode == 200 { return .success(data) }
            if statusCode == 401 { return .unauthorized }
            if statusCode == 429 {
                let retryAfter = Double(httpResponse?.value(forHTTPHeaderField: "Retry-After") ?? "30") ?? 30
                return .rateLimited(retryAfter)
            }
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            return .error("API \(statusCode): \(body.prefix(100))")
        } catch {
            return .error("API: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain

    private func getKeychainData() -> [String: Any]? {
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func getOAuthToken() -> String? {
        guard let json = getKeychainData(),
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    private func isTokenExpired() -> Bool {
        guard let json = getKeychainData(),
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let expiresAt = oauth["expiresAt"] as? Double else {
            return true
        }
        // 만료 5분 전부터 갱신
        return Date().timeIntervalSince1970 * 1000 >= expiresAt - 300_000
    }

    private func refreshOAuthToken() async -> Bool {
        guard let json = getKeychainData(),
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let refreshToken = oauth["refreshToken"] as? String else {
            return false
        }

        guard let url = URL(string: "https://api.anthropic.com/oauth/token") else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=claude-code"
        req.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else { return false }

            guard let tokenResp = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess = tokenResp["access_token"] as? String,
                  let newRefresh = tokenResp["refresh_token"] as? String,
                  let expiresIn = tokenResp["expires_in"] as? Double else {
                return false
            }

            // Keychain 업데이트
            var updatedJson = json
            var updatedOAuth = oauth
            updatedOAuth["accessToken"] = newAccess
            updatedOAuth["refreshToken"] = newRefresh
            updatedOAuth["expiresAt"] = (Date().timeIntervalSince1970 + expiresIn) * 1000
            updatedJson["claudeAiOauth"] = updatedOAuth

            guard let newData = try? JSONSerialization.data(withJSONObject: updatedJson) else {
                return false
            }

            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "Claude Code-credentials"
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String: newData
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
            return updateStatus == errSecSuccess
        } catch {
            return false
        }
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Menu bar label

    var menuBarLabel: String {
        guard let fiveH = oauthUsage?.fiveHour else { return "--" }
        return "\(Int(fiveH.utilization))% \(fiveH.timeUntilReset)"
    }
}
