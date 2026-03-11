# ClaudeUsageBar

macOS menu bar app that shows your Claude Code usage at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **5-hour rate limit** — utilization % and reset countdown
- **7-day rate limits** — overall, Opus, Sonnet breakdown (when applicable)
- **Extra credits** — monthly limit vs used
- **Auto token refresh** — refreshToken으로 자동 갱신, Claude Code 미사용 시에도 독립 동작
- **Auto-refresh** every 2 minutes

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools: `xcode-select --install`
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and logged in

## Install

```bash
git clone https://github.com/codeseren/ClaudeUsageBar.git
cd ClaudeUsageBar
bash bundle.sh
```

The app appears in your menu bar with a sparkle icon. Click to see the full dashboard.

## How it works

| Data | Source |
|------|--------|
| Rate limits (5h, 7d, per-model) | `GET api.anthropic.com/api/oauth/usage` via OAuth token |
| OAuth token | macOS Keychain (`Claude Code-credentials`) |

No API keys to configure. Everything comes from your existing Claude Code installation.

## Auto-start on login (optional)

1. Open **System Settings → General → Login Items**
2. Click **+** and select `~/Applications/ClaudeUsageBar.app`

## Changelog

### v1.1.0 (2026-03-12)

- **OAuth 토큰 자동 갱신**: Claude Code를 사용하지 않아도 refreshToken으로 토큰을 자체 갱신하여 독립 동작
- **401 응답 시 자동 재시도**: 토큰 만료로 인한 API 실패 시 갱신 후 재시도
- **로컬 stats-cache 의존 제거**: `~/.claude/stats-cache.json`은 Claude Code 내부에서만 갱신되어 데이터가 오래될 수 있었음. Today/Weekly/Activity Chart/Model Usage 섹션 삭제
- **OAuth Usage API만으로 구성**: 5-hour, 7-day, per-model(Opus/Sonnet), Extra Credits — 실시간 데이터만 표시
- UI 경량화 (고정 높이 제거, 폭 축소)

### v1.0.1 (2026-03-10)

- OAuth API 429 대응: `User-Agent` 헤더 추가, retry 로직

### v1.0.0 (2026-03-10)

- Initial release

## License

MIT
