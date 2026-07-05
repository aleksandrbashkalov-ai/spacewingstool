---
name: workspace-management
description: Analyze open applications, detect user context, suggest and switch workspaces automatically. Monitor for trigger matches and handle space transitions.
---

# Workspace Management

## What I do
- Monitor running applications and their windows via Accessibility API
- Match current workspace state against configured Space triggers
- Auto-activate Space when trigger conditions are met
- Save and restore window layouts for each Space
- Capture full workspace snapshots for later restoration

## When to use
Use this skill when working on workspace detection, trigger matching, space transitions, or window layout management.

## Core Files
- `Sources/Services/SpaceManager.swift` — Space lifecycle management
- `Sources/Services/WindowMonitor.swift` — Window observation and tracking

## Trigger Types
| Type | Description | Example |
|------|-------------|---------|
| `appRunning` | Apps with matching bundle IDs are open | Xcode, VSCode → Coding |
| `urlPattern` | Browser URLs match pattern | github.com → Coding |
| `timeRange` | Current time falls in range | 9-12am → Deep Work |
| `calendarEvent` | Calendar event title matches keywords | "Meeting" → Meetings |
| `focusMode` | Specific Focus mode is active | "Work" → Deep Work |

## Best Practices
- Poll windows at 2s intervals for responsiveness without battery drain
- Cache AXUIElement references to minimize Accessibility API calls
- Use NSWorkspace notifications for real-time context changes
- Always handle Accessibility API failures gracefully with fallbacks
- Log all state transitions with Logger

## Architecture
```
WindowMonitor → ContextAnalyzer → SpaceManager → NSWorkspace
      ↓              ↓                ↓
  AX APIs     AI Classification   Space Activation
```
