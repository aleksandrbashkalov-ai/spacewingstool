# Spacewingstool — AI Workspace Manager

## Project Overview

Spacewingstool is a native macOS application built with Swift 5.10 (Xcode 15.3+), SwiftUI + AppKit that serves as an intelligent, context-aware workspace manager. It automatically creates, switches, and optimizes workspaces (Spaces) based on real-time analysis of open applications, active windows, calendar events, focus mode, and time of day.

**Universal binary**: Supports both Intel (x86_64) and Apple Silicon (arm64).
**Deployment target**: macOS 14 (Sonoma) and later. Forward-compatible with all future versions.
**Distribution**: Free & open-source on GitHub (MIT). NOT on Mac App Store — no sandbox, no entitlements needed.
**Signing**: Ad-hoc signing with free Apple ID is sufficient. No paid Apple Developer Program required.
**Dependencies**: GRDB only. Local AI via NLTagger (built-in). Remote AI via OpenAI-compatible API (optional).
**Energy efficient**: Adaptive polling based on thermal state, background activity assertion, lightweight polling timer.

### Core Principles
- **On-device AI**: All analysis happens locally via Core ML and Natural Language framework
- **Privacy-first**: No data leaves the device
- **Native performance**: Built entirely with Apple frameworks for minimal battery impact
- **Progressive disclosure**: Simple for beginners, powerful for power users

## Rules

### Code Style
- All source files are in `Sources/` with subdirectories: `App/`, `Models/`, `Services/`, `Stores/`, `UI/`, `Utilities/`
- Follow Swift API Design Guidelines — use clear, descriptive names
- Use `@Observable` macro for state management (macOS 14+)
- Use `actor` for service classes that manage shared state or system resources
- No comments unless documenting public API surface or complex logic
- Use `Logger` for all logging — never use `print()`
- All UI views should be in their own file under `Sources/UI/`
- Follow MVVM pattern with Store classes using `@Observable`

### Architecture Rules
- Services are actors accessed via `.shared`
- Stores are `@Observable` classes on `@MainActor`
- UI never directly accesses Services — always goes through Stores
- All async operations use structured concurrency
- Background tasks must use `Task { ... }` with explicit actor isolation
- Never block the main thread — use async/await for any I/O
- Use `@Environment` for injecting Stores into Views (with `@Observable` + `@Bindable`)
- Use `MenuBarExtra` with `.menuBarExtraStyle(.window)` instead of `NSStatusItem` + `NSMenu`
- Protocol-based DI available via `Sources/Services/ServiceProtocols.swift`

### File Organization
```
Sources/
├── App/                    # App entry point, AppDelegate
├── Models/                 # SwiftData models, value types
├── Services/               # Business logic, system integration
├── Stores/                 # Observable state containers
├── UI/                     # SwiftUI views
└── Utilities/              # Extensions, helpers, constants
```

### Testing Rules
- Use `XCTest` framework (Swift 6+ should migrate to Swift Testing)
- Test files go in `Tests/` mirroring `Sources/` structure
- Unit test all Services and Stores
- Use mock services for UI testing via protocol-based DI (`Sources/Services/ServiceProtocols.swift`)
- Tests must be isolated — use `setUp`/`tearDown` and restore modified singleton state
- Minimum 80% code coverage for Services

## Tools

### Build & Develop
```bash
# Build the project (native arch)
swift build

# Build universal binary (Intel + Apple Silicon)
swift build -c release --arch arm64 --arch x86_64

# Build with release configuration (native arch)
swift build -c release

# Open in Xcode
xed .

# Run tests
swift test
```

### Code Generation
```bash
# Create a new SwiftUI view file
touch Sources/UI/<ViewName>.swift

# Create a new service
touch Sources/Services/<ServiceName>.swift
```

### Debugging
```bash
# Watch logs in real-time
log stream --predicate 'subsystem == "com.spacewingstool"' --level debug

# Monitor energy impact
sudo powermetrics --samplers tasks -i 5000

# Check accessibility permissions
tccutil reset AppleEvents com.spacewingstool.app
```

### Git Workflow
- Branch naming: `feature/<name>`, `fix/<name>`, `refactor/<name>`
- Commit messages: conventional commits (feat:, fix:, refactor:, docs:)
- Squash commits before merging to main

## Skills

### Workspace Management
Analyze open applications, detect user context, suggest and switch workspaces automatically. Monitor for trigger matches and handle space transitions.

### AI Context Analysis
Use Apple Intelligence and Core ML to classify user activity into modes (Deep Work, Coding, Meetings, Creative). Extract entities from window titles and URLs. Estimate productivity levels based on app usage patterns.

### Session Memory
Capture full workspace snapshots including app positions, open tabs, and window states. Support restoring previous sessions on demand. Track productivity metrics over time.

### System Integration
Monitor running applications via Accessibility API and NSWorkspace notifications. Read Calendar events for context detection. Support global keyboard shortcuts for quick actions.

## OpenCode Configuration

This project uses OpenCode with the following setup:
- **Config**: `opencode.json` — project-level configuration
- **Agents**: `.opencode/agents/*.md` — specialized subagents
- **Skills**: `.opencode/skills/*/SKILL.md` — on-demand loaded skills
- **Commands**: `.opencode/commands/*.md` — quick-action commands

### Available Commands
| Command | Description |
|---------|-------------|
| `/build-test` | Build and run all tests |
| `/test-verbose` | Run tests with verbose output |
| `/new-view <name>` | Create a new SwiftUI view |
| `/new-service <name>` | Create a new service |
| `/lint` | Run SwiftLint |
| `/watch-logs` | Stream app logs in real-time |
| `/build-universal` | Build universal binary |

### Available Skills
| Skill | Description |
|-------|-------------|
| `workspace-management` | Workspace detection and trigger logic |
| `ai-context-analysis` | AI/ML context classification |
| `session-memory` | Snapshot capture and persistence |

### Available Agents
| Agent | Mode | Description |
|-------|------|-------------|
| `workspace-logic-specialist` | subagent | SpaceManager, WindowMonitor |
| `ai-ml-specialist` | subagent | AIService, ContextAnalyzer |
| `ui-ux-specialist` | subagent | All SwiftUI views |
| `data-persistence-specialist` | subagent | Models, MemoryService |

## Quick Reference

### Space Trigger Types
| Trigger | Description | Example |
|---------|------------|---------|
| `appRunning` | Apps with matching bundle IDs are open | Xcode, VSCode → Coding |
| `urlPattern` | Browser URLs match pattern | github.com → Coding |
| `timeRange` | Current time falls in range | 9-12am → Deep Work |
| `calendarEvent` | Calendar event title matches keywords | "Meeting" → Meetings |
| `focusMode` | Specific Focus mode is active | "Work" → Deep Work |

### Key Constants
- Default polling interval: 2.0s
- Snapshot retention: 30 days
- Максимальна кількість просторів: необмежено
- Максимальна кількість знімків: 50
