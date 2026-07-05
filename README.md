# Spacewingstool

> AI-native macOS workspace manager. Automatically creates, switches, and optimizes workspaces based on what you're doing.

<p align="center">
  <img src="Resources/logo.png" alt="Spacewingstool" width="128">
</p>

<p align="center">
  <b>Requirements:</b> macOS 14 (Sonoma) or later &bull; Apple Silicon or Intel
  <br>
  <b>License:</b> MIT &bull; <a href="PRIVACY.md">Privacy</a>
</p>

## Features

- **Smart context detection** — analyzes open apps, windows, calendar, and focus mode
- **Auto-switch spaces** — automatically transitions between workspaces
- **Activity tracking** — reading, writing, email, media, meetings (all **off by default**)
- **AI productivity coach** — local NLP-based insights and recommendations
- **Session memory** — capture and restore workspace snapshots
- **Privacy-first** — all data stays on your Mac unless you explicitly enable Remote AI

## Quick Start

### From source

```bash
git clone https://github.com/<your-username>/Spacewingstool.git
cd Spacewingstool
swift run
```

### Requirements

- macOS 14 Sonoma or later
- Xcode 15.3+ or Command Line Tools
- Swift 5.10+

### First launch

1. Grant Accessibility permission when prompted (required for window monitoring)
2. Configure tracking categories in Settings → Privacy (all disabled by default)
3. Optionally enable AI Enhancement in Settings → AI

## Build

```bash
# Debug build
swift build

# Release build (native arch)
swift build -c release

# Universal binary (Intel + Apple Silicon)
swift build -c release --arch arm64 --arch x86_64

# Run tests
swift test
```

## Privacy

All tracking features are **off by default**. You explicitly opt in per category.

- **Local storage only** — SQLite database in `~/Library/Application Support/`
- **No telemetry** — no analytics, no tracking SDKs
- **Remote AI is opt-in** — data leaves your device only if you configure and enable it
- **Delete anytime** — "Delete All Data" button in Settings

See [PRIVACY.md](PRIVACY.md) for details.

## Configuration

Settings are stored in `UserDefaults` and the activity database at:
```
~/Library/Application Support/com.spacewingstool.app/
```

Key preferences:
- Polling interval (default: 2s)
- Data retention (default: 30 days)
- Per-category tracking toggles
- AI provider (local/remote) and endpoint

## Project Structure

```
Sources/
├── App/          # App entry point, lifecycle
├── Models/       # Data types, PrivacySettings
├── Services/     # Trackers, AI providers, database
├── Stores/       # Observable state (SettingsStore, SpaceStore)
├── UI/           # SwiftUI views
└── Utilities/    # Extensions, helpers, localization
```

## Dependencies

- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite database

## Roadmap

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full development roadmap.

## Contributing

Contributions welcome! Please open an issue or pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## License

[MIT](LICENSE)
