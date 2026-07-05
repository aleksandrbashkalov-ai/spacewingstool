---
name: session-memory
description: Capture full workspace snapshots, track productivity metrics over time, and restore previous sessions on demand.
---

# Session Memory

## What I do
- Capture complete workspace state (app positions, windows, tabs)
- Restore any previous session on demand
- Track time spent per Space and per application
- Log context switches and productivity scores

## When to use
Use this skill when working on session snapshots, productivity tracking, or data persistence.

## Core Files
- `Sources/Services/MemoryService.swift` — Session capture and restore
- `Sources/Models/SessionSnapshot.swift` — Snapshot data model
- `Sources/Models/ProductivityStats.swift` — Productivity metrics
- `Sources/Utilities/PersistenceService.swift` — SwiftData persistence

## Data Models
| Model | Purpose |
|-------|---------|
| Space | Workspace definition with triggers |
| SessionSnapshot | Complete workspace state capture |
| ProductivityStats | Time tracking and productivity scores |
| Context | Current user context state |

## Retention Policy
- Default snapshot retention: 30 days
- Maximum snapshots: 50
- Auto-capture on Space switch
- Manual naming for important snapshots
- Background cleanup of old snapshots

## Best Practices
- Auto-capture snapshots when switching Spaces
- Allow manual naming of important snapshots
- Clean up old snapshots periodically in background
- Don't exceed 50 snapshots to manage storage
- Never block the main thread for data operations
