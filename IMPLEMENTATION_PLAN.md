# Spacewingstool — Activity Intelligence Platform

## Vision
AI-native macOS assistant that tracks everything, understands context, and delivers actionable intelligence — all privacy-first, fully under user control.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                      ActivityTracker                       │
│  (actor — orchestrates all trackers, manages lifecycle)    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Reading  │ │ Writing  │ │  Email   │ │  Media   │    │
│  │ Tracker  │ │ Tracker  │ │ Tracker  │ │ Tracker  │    │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘    │
│       │            │            │            │           │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐    │
│  │ Meeting  │ │ Calendar │ │  Focus   │ │  Other   │    │
│  │ Tracker  │ │ Tracker  │ │  Tracker │ │ Trackers │    │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘    │
│                                                           │
├──────────────────────────────────────────────────────────┤
│                      Storage Layer                         │
│  SQLite (GRDB) + FTS5 + Keyframe/Delta compression        │
├──────────────────────────────────────────────────────────┤
│                      AI Layer                              │
│  AIOrchestrator → AIProvider (Local/Remote)               │
│  → Summaries, Reports, Pattern Detection, Suggestions     │
├──────────────────────────────────────────────────────────┤
│                      Sync Layer                            │
│  CloudKit (optional) → iCloud Private DB                  │
└──────────────────────────────────────────────────────────┘
```

---

## Phase 0: Foundation (Week 1-2)

### 0.1 Architecture Setup
- Create `Sources/Services/ActivityTracker/` directory
- `ActivityTracker.swift` — main actor, manages lifecycle of all sub-trackers
- `ActivityRecord.swift` — unified activity model
- `ActivityDatabase.swift` — SQLite (GRDB) with FTS5, keyframe/delta compression

### ActivityRecord Schema (SQLite)
```sql
CREATE TABLE activities (
    id TEXT PRIMARY KEY,
    timestamp REAL NOT NULL,
    activity_type TEXT NOT NULL,  -- reading, writing, email, media, meeting
    category TEXT,                 -- browser, pdf, ide, mail, music, video
    app_bundle_id TEXT,
    app_name TEXT,
    title TEXT,                    -- page title, doc name, email subject, song title
    content_excerpt TEXT,          -- truncated preview / summary
    metadata_json TEXT,            -- type-specific metadata (JSON blob)
    duration REAL,                 -- seconds spent
    confidence REAL,               -- 0.0-1.0
    source TEXT,                   -- accessibility, applescript, vision, manual
    is_summarized INTEGER DEFAULT 0,
    summary_id TEXT
);

CREATE VIRTUAL TABLE activities_fts USING fts5(
    title, content_excerpt, metadata_json,
    content='activities', content_rowid='rowid'
);

CREATE INDEX idx_activities_timestamp ON activities(timestamp);
CREATE INDEX idx_activities_type ON activities(activity_type);
CREATE INDEX idx_activities_app ON activities(app_bundle_id);
```

### 0.2 Permissions System
- `PermissionsManager.swift` — unified permission state machine
- Tracks: Accessibility, Screen Recording, Microphone, Input Monitoring, Full Disk Access, Calendar, Notifications
- Onboarding UI for each permission with clear explanation
- Graceful degradation: if permission denied, tracker shows "limited mode"
- **Recording indicator**: menu bar icon changes to "recording" state (red dot / pulsing) while any tracker captures content (per Guideline 2.5.14)
- Optional audible alert on first capture of each session

### 0.3 Privacy Controls
- `PrivacySettingsView.swift` — per-category toggles:
  - Track Reading: on/off, content capture: full/preview/off
  - Track Writing: on/off, capture content: on/off (metadata only)
  - Track Email: on/off, capture body: full/preview/off
  - Track Music: on/off
  - Track Meetings: on/off, record audio: on/off
- Data retention: 7/30/90 days / forever
- "Delete all data" button per category
- Local-only indicator: "All data stays on this Mac" / "AI uses remote provider"
- **Remote AI consent screen**: before enabling, user must explicitly agree to data leaving device (Guideline 5.1.2(i))
- **Login item**: must ask user consent before adding to Login Items (Guideline 2.4.5(iii))

### 0.4 Privacy Policy & Manifest
- In-app privacy policy view: `PrivacyPolicyView.swift` with link to full policy (Guideline 5.1.1(i))
- `PrivacyInfo.xcprivacy` manifest declaring Required Reason APIs:
  - File Timestamp API (Accessibility events → file access timestamps)
  - System Boot Time API (uptime tracking)
  - Disk Space API (storage for activity DB)
- Paid features must never require mandatory permission grants (Guideline 5.1.1(ii))

---

## Phase 1: Reading Tracker (Week 2-3)

### 1.1 Browser Content Capture
- **AppleScript injection**: `document.body.innerText` + headings + links + meta
  - Safari, Chrome, Arc, Brave, Edge, Firefox
  - On tab switch / periodic (every 5s while active tab is focused)
  - Diff: detect what's *new* vs already read
- **Reading state machine**: AXObserver (focus changed) + scroll events
  - `AXWebArea` focused → "reading" state
  - Scroll events → "scrolling" (reset idle timer)
  - No scroll + no key for 3s → back to "reading"
  - Tab switch → capture + summarize

### 1.2 PDF & Document Reader
- PDF: AX role detection (`AXPDFView`) + PDFKit content extraction
  - Track page number, document title, time per page
  - Annotations (highlight, note)
- Apple Books / Kindle: AppleScript for current book, page, reading time

### 1.3 Reading Session Tracking
- `ReadingSession` model:
  - Start time, end time, duration
  - Source (URL / PDF / book)
  - Estimated words read (content length * reading speed heuristic)
  - Scroll depth (% of page)
  - Active reading time vs idle time
- Session ends on: tab close, app switch for 5+ min, sleep, lock

### 1.4 Reading Summarization
- On session end: AI summarizes what was read (3-5 key points)
- Content truncated to ~4000 tokens, AI generates:
  - Summary (2-3 sentences)
  - Key takeaways (bullets)
  - Related topics / tags
- Stored as `ActivityRecord` with `activity_type: "reading"`

---

## Phase 2: Writing Tracker (Week 3)

### 2.1 Typing Activity Monitor
- **Privacy-first**: NEVER record keystrokes literally
- Use `CGEventTap` (keydown count + duration) + `AXFocusedUIElementChanged`
- Track:
  - Per-app, per-document: time spent typing, words typed estimate
  - Active vs idle typing time (auto-repeat filter)
  - Keystroke count, modified text length
- **No content capture** by default — only metadata (app, document, duration, wpm)

### 2.2 Smart Text Capture (Opt-in)
- When user explicitly enables "capture writing content":
  - Capture selected text on copy (⌘C)
  - Capture focused text field content on app switch
  - Diff consecutive captures to detect new content
- Content sent to AI for summarization:
  - What was written: topic, key points, changes
  - Writing patterns: time of day, productivity by topic

### 2.3 App-Specific Trackers
- **Xcode**: AX for current file, line range, build status, debug mode
- **VS Code**: AX for active file, cursor position, terminal view
- **Notes/Bear/Obsidian**: AppleScript for current note, word count, changes
- **Messages/Slack**: AX for conversation title, participant count, message count

---

## Phase 3: Email Tracker (Week 3-4)

### 3.1 Apple Mail Integration
- **AppleScript bridge** (`NSAppleScript`):
  - New message notification: `Mail` distributed notifications
  - Extract: sender, recipients, subject, date, body (plain text)
  - Thread detection: message-id, references headers
- **Polling**: check inbox every 60s for new messages since last check

### 3.2 Gmail / Outlook via Browser
- When Gmail/Outlook tab is active in browser:
  - Extract thread titles, senders, email addresses
  - Detect new vs read messages
  - Thread context (previous messages in thread)

### 3.3 Intelligent Email Processing
- AI-powered extraction:
  - **Action items**: "Please review by Friday" → task with deadline
  - **Dates/deadlines**: NLP date extraction (Friday = next Friday)
  - **Tasks**: "Can you send me the report?" → follow-up task
  - **Meeting invites**: calendar event auto-detection
  - **Priority**: urgency classification (sender, subject keywords, response time)
- Stored as:
  - `ActivityRecord` with `activity_type: "email"`
  - `Task` record if action item detected

### 3.4 Email Summarization
- Per-thread: AI summary of conversation
- Daily email digest: "Today you received 23 emails, 5 required action"
- Deadline aggregation: "Upcoming deadlines: PR review Fri, Tax filing Apr 15"

---

## Phase 4: Media Tracker (Week 4)

### 4.1 Now Playing Detection
- **Primary**: AppleScript for Spotify + Apple Music
  ```applescript
  tell application "Spotify"
      set t to name of current track
      set a to artist of current track
      set alb to album of current track
      return t & "|||" & a & "|||" & alb
  end tell
  ```
- **Fallback**: MediaRemote private framework (for browser-based players, etc.)
  - `kMRMediaRemoteNowPlayingInfoDidChangeNotification`
  - Track: title, artist, album, duration, playback rate, genre
  - Cross-app (works for YouTube Music, SoundCloud, etc.)

### 4.2 Listening Session Tracking
- Session: from play → pause/stop/track change
- Track: start time, duration, platform
- Per-session: all tracks listened to (no duplicates in a row)
- Daily listening summary: time spent, top artists, genres

### 4.3 Integration with Productivity Context
- Correlate music with activity:
  - "When coding in Xcode, you listen to lo-fi 80% of the time"
  - "Your productivity is 15% higher when listening to ambient music"
- Music state in context: `DetectedContext.currentlyListening`

---

## Phase 5: Meeting Tracker (Week 4-6)

### 5.1 Meeting Detection
- **App detection**: AX / NSWorkspace for Zoom, Teams, Meet, Webex, Slack Huddles
- **Window title parsing**: "Zoom Meeting | Project Sync" → extract meeting name
- **Calendar correlation**: match active meeting with calendar event
- **State machine**:
  - Meeting app focused + window title contains meeting keywords → "in meeting"
  - Track: start time, platform, meeting title (from window / calendar)

### 5.2 Participant Detection
- **Calendar attendees**: EventKit participant list (when matched with event)
- **Window UI**: AX for participant list in meeting app
- **Chrome tab**: Google Meet participant count via AX tree
- Store: participant names, count, organization (email domain)

### 5.3 Duration & Engagement Tracking
- Meeting start → end (app focus + window closed)
- Active time vs background time (user in meeting app vs other apps)
- "Was the user presenting, sharing screen, or just listening?"
  - Screen sharing: detect via AX / window title ("is presenting")
  - Speaking: detect via microphone activation (AVAudioEngine level)

### 5.4 Transcription (Advanced — Opt-in)
- **Requires**: Microphone + Screen Recording + Speech Recognition permissions
- **Audio sources**:
  - User's voice: `AVAudioEngine` (microphone)
  - Others' voices: `ScreenCaptureKit` (system audio)
- **Recognition**:
  - `SFSpeechRecognizer` (on-device, 60+ languages)
  - `WhisperKit` (Metal-accelerated, more accurate)
- **Storage**: Text only, no audio. Speaker-labeled if possible.
- **Summarization**: AI generates meeting notes:
  - Attendees
  - Key discussion points
  - Decisions made
  - Action items (with assignees)
  - Follow-up tasks

---

## Phase 6: Activity Intelligence & Reports (Week 6-7)

### 6.1 Activity Database
- SQLite (GRDB) with all activity records
- FTS5 full-text search across all content
- Timeline view: scrollable activity feed with filters

### 6.2 AI Summarization Pipeline
- **On session end**: per-session summary (reading, writing, meeting)
- **Daily at 9pm**: daily report:
  - "You spent 4h coding, 2h in meetings, read 3 articles"
  - "You wrote ~1500 words across 5 documents"
  - "New from email: 3 deadlines this week"
  - "Productivity score: 78/100"
- **Weekly on Sunday**: weekly insights:
  - Trends: "Your deep work hours dropped 20% this week"
  - Suggestions: "Block 10-12am for focused work"
  - Top distractions, most productive times, app usage breakdown

### 6.3 Task Extraction & Tracking
- Tasks extracted from:
  - Email: "Please review PR by Friday"
  - Meetings: "Alex will send the spec"
  - Notes: "TODO: update dependencies"
  - Explicit user input: "Remind me to file taxes"
- Task model:
  - Description, source, deadline, priority, status
  - Auto-suggest: "This email mentions a deadline of Friday — add task?"
- Task list UI in menu bar app

### 6.4 Query Interface
- Natural language query via AI:
  - "What did Alex say in the meeting yesterday?"
  - "What was I working on Thursday afternoon?"
  - "When is the tax deadline from my email?"
  - "Show me this week's productivity report"
- Local-only: queries run against local SQLite + local AI
- Remote: optional enhanced understanding via API

---

## Phase 7: AI Provider System (Week 7-8)

### 7.1 AIProvider Protocol
```swift
protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isLocal: Bool { get }
    var supportsStreaming: Bool { get }
    var supportsFunctions: Bool { get }
    func complete(prompt: String, context: AIContext) async throws -> String
    func stream(prompt: String, context: AIContext) -> AsyncThrowingStream<String, Error>
    func structured<T: Decodable>(prompt: String, schema: T.Type) async throws -> T
}
```

### 7.2 Provider Implementations
- **LocalAI Provider** (mlx-swift):
  - Uses Apple Silicon GPU/ANE
  - Default model: Llama-3.2-1B-Instruct (downloaded on first use, ~800MB)
  - All processing on-device, zero network
  - Slower but completely private

- **Ollama Provider**:
  - Connects to `http://localhost:11434`
  - User chooses model
  - Works with any Ollama-compatible backend

- **OpenAI-Compatible Provider**:
  - OpenAI, Anthropic, Groq, Together, LocalAI server, etc.
  - Configurable endpoint URL, API key, model name
  - Keychain-stored API keys

### 7.3 AI Capabilities & Routing

| Capability | Local AI | Remote AI | Default |
|-----------|----------|-----------|---------|
| Reading summary | ✅ (slower) | ✅ | Local |
| Writing patterns | ✅ | ✅ | Local |
| Email processing | ✅ | ✅ | Remote (better NER) |
| Meeting transcription | WhisperKit | Cloud API | Local |
| Daily report | ✅ | ✅ | Remote |
| Weekly insights | ⚠️ (limited) | ✅ | Remote |
| Task extraction | ⚠️ (limited) | ✅ | Remote |
| Query answering | ⚠️ (small context) | ✅ | Remote |
| Intent classification | ✅ | ✅ | Local |

### 7.4 Prompt Templates
- `Resources/Prompts/` directory:
  - `reading-summary.system.txt`
  - `writing-analysis.system.txt`
  - `email-summary.system.txt`
  - `meeting-notes.system.txt`
  - `daily-report.system.txt`
  - `weekly-insights.system.txt`
  - `task-extraction.system.txt`
  - `query-answering.system.txt`

---

## Phase 8: Localization + iCloud Sync (Week 8-9)

### 8.1 Localization (5 languages)
- `Localizable.xcstrings` — all UI strings
- `en` (default), `es`, `fr`, `de`, `ar`
- Arabic: full RTL support (`environment(\.layoutDirection, .rightToLeft)`)
- Language picker in Settings → General
- Applies immediately without restart

### 8.2 iCloud Sync
- CloudKit private database
- **Per-category toggles**: Spaces, Settings, Activity Log, Snapshots
- **Local-first**: write to local SQLite immediately, enqueue CK sync
- **Conflict resolution**: last-write-wins per record (with blame tracking)
- **Compression**: large activity records compressed before upload
- **Sync UI**: last sync time, pending count, manual "Sync Now"
- **Versioned settings**: timeline of changes (who changed what, when)

---

## Phase 9: Settings Migration — Versioned Settings Timeline (Week 9)

### 9.1 Versioned Settings (The Unique Feature)
- Every setting change is a "commit":
  - Timestamp, old value, new value, source (user / AI / context)
  - Stored in SQLite `settings_history` table
- **Timeline UI**: browse history like `git log`
- **Rollback**: restore any previous state
- **AI-suggested settings**: "I noticed you disable notifications during coding — enable automatically?"
  - Suggestion appears as pending commit
  - User approves or rejects

### 9.2 Context Profiles
- Different settings profiles for different contexts:
  - Deep Work: polling 0.5s, notifications off, track writing only
  - Meetings: polling 3s, full meeting tracking, transcription on
  - Browsing: polling 1s, track reading, pause productivity scoring
- Profiles auto-activate when context changes

### 9.3 Migration from UserDefaults
- First launch after update: migrate all settings from `UserDefaults` → SQLite
- Backup old `UserDefaults` to file
- One-way migration, never revert

---

## Privacy & Security Model

### Data Classification
| Category | Default | Stored | Encryption |
|----------|---------|--------|------------|
| Reading content | On (preview only) | Local SQLite | Full disk |
| Writing metadata | On | Local SQLite | Full disk |
| Writing content | Off | Local SQLite | Full disk |
| Email metadata | On | Local SQLite | Full disk |
| Email body | Off (preview only) | Local SQLite | Full disk |
| Music listening | On | Local SQLite | Full disk |
| Meeting metadata | On | Local SQLite | Full disk |
| Meeting audio | Off | Not stored | N/A |
| Meeting transcript | Off | Local SQLite | Full disk |

### User Controls
- One-click "Delete all data" per category
- Data retention: 7/30/90 days / forever
- Export all data as JSON
- Clear indicator when AI uses remote vs local
- No data ever sent to third parties without explicit opt-in

---

## Permission Requirements

| Permission | Trackers | Info.plist Key |
|-----------|----------|----------------|
| Accessibility | Reading, Writing, Email, Meetings | `NSAppleEventsUsageDescription` |
| Screen Recording | Meetings (transcription) | `NSScreenCaptureUsageDescription` |
| Microphone | Meetings (user's voice) | `NSMicrophoneUsageDescription` |
| Speech Recognition | Meetings (transcription) | `NSSpeechRecognitionUsageDescription` |
| Input Monitoring | Writing (keystroke stats) | — (requires code signing) |
| Full Disk Access | Email (Mail SQLite) | — |
| Calendar | Meetings, Email | `NSCalendarsFullAccessUsageDescription` |
| Notifications | All | `NSUserNotificationAlertStyle` |
| iCloud | Sync | `com.apple.developer.icloud-services` |

---

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Database | GRDB (SQLite + FTS5) |
| Local AI | mlx-swift (GPU/ANE) |
| Remote AI | OpenAI-compatible API |
| Speech | SFSpeechRecognizer + WhisperKit |
| Audio capture | ScreenCaptureKit + AVAudioEngine |
| UI | SwiftUI (macOS 14+) |
| Sync | CloudKit |
| Keychain | Keychain Services API |
| Now Playing | MediaRemote (private) + AppleScript |

---

## Estimated Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 0. Foundation | 2 weeks | Architecture, DB, permissions, privacy |
| 1. Reading Tracker | 2 weeks | Browser, PDF, reading sessions, summaries |
| 2. Writing Tracker | 1 week | Typing monitor, text capture, app-specific |
| 3. Email Tracker | 1 week | Mail bridge, Gmail, action items |
| 4. Media Tracker | 1 week | Now playing, listening sessions |
| 5. Meeting Tracker | 2 weeks | Detection, participants, transcription |
| 6. Activity Intelligence | 2 weeks | Reports, tasks, query interface |
| 7. AI Providers | 2 weeks | Local + remote, prompt system |
| 8. Localization + Sync | 2 weeks | 5 languages, iCloud sync |
| 9. Settings Timeline | 1 week | Versioned settings, rollback |
| **Total** | **~14 weeks** | |

---

## Summary

This turns Spacewingstool from a workspace manager into a **full Activity Intelligence Platform**:

- **Track everything**: reading, writing, email, music, meetings
- **Understand everything**: AI summarizes, extracts tasks, detects patterns
- **Report everything**: daily/weekly insights, customizable
- **Privacy-first**: all data local by default, user controls every category
- **Settings versioning**: unique timeline + rollback + AI suggestions

Ready when you are. Say "go" and I start building Phase 0.