# ClaudeUsageBar

macOS menu bar app that shows your Claude Code usage at a glance.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **5-hour / Weekly rate limits** — utilization % and reset countdown
- **Per-model weekly limits** — Opus, Sonnet breakdown (when applicable)
- **Extra credits** — monthly limit vs used
- **Today's activity** — messages, tool calls, sessions
- **Recent activity chart** — last 14 days bar chart
- **All-time model usage** — output tokens by model
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
| Rate limits (5h, 7d) | `GET api.anthropic.com/api/oauth/usage` via OAuth token |
| Activity & tokens | `~/.claude/stats-cache.json` (local) |
| OAuth token | macOS Keychain (`Claude Code-credentials`) |

No API keys to configure. Everything comes from your existing Claude Code installation.

## Auto-start on login (optional)

1. Open **System Settings → General → Login Items**
2. Click **+** and select `~/Applications/ClaudeUsageBar.app`

## License

MIT
