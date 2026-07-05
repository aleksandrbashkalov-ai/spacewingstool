# Spacewingstool Privacy

## What data is collected

Spacewingstool can track your app usage to provide intelligent workspace features. All tracking is **off by default** and must be explicitly enabled per category:

- **Reading**: Browser URLs, page titles, scroll depth, reading time
- **Writing**: App name, document title, typing duration & speed (no keystroke content)
- **Email**: Sender, subject, thread info (body only with explicit opt-in)
- **Media**: Track title, artist, playback duration
- **Meetings**: Meeting title, platform, duration (audio recording requires separate opt-in)
- **Activity**: Active app names, window titles, focus/calendar context

## Where data is stored

**All data is stored locally** on your Mac in:
- `~/Library/Application Support/com.spacewingstool.app/` (SQLite database)
- Keychain (API keys, if Remote AI is enabled)

No data is sent anywhere unless you explicitly:
1. Enable **Remote AI** in Settings (data sent to your configured endpoint)
2. Use the **Export** button to save a JSON file

## Data deletion

- **Retention**: Automatic deletion after configurable period (default 30 days)
- **Manual**: "Delete All Collected Data" button in Settings → Privacy
- **Per-category**: Individual toggles to stop collection at any time

## Third-party services

Spacewingstool has no third-party analytics, telemetry, or tracking SDKs.

The only optional network connection is to your configured Remote AI endpoint (off by default).
