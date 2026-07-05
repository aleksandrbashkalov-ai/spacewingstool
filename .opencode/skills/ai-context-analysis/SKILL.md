---
name: ai-context-analysis
description: Use Apple Intelligence and Core ML to classify user activity into modes and estimate productivity. Extract entities from window titles and URLs.
---

# AI Context Analysis

## What I do
- Classify user activity into SpaceMode (Deep Work, Coding, Meetings, Creative, etc.)
- Extract named entities from window titles and URLs using NLTagger
- Estimate productivity level based on app usage patterns
- Suggest optimal Space based on multimodal context analysis

## When to use
Use this skill when working on context classification, productivity analysis, or AI-powered features.

## Core Files
- `Sources/Services/AIService.swift` — AI service coordination
- `Sources/Services/ContextAnalyzer.swift` — Context analysis logic

## Classification Keywords
| Mode | Keywords |
|------|----------|
| Coding | xcode, vscode, intellij, terminal, swift, python, github |
| Creative | final cut, affinity, photoshop, illustrator, garageband |
| Meetings | zoom, teams, meet, facetime, meeting, call, standup |
| Deep Work | obsidian, notion, bear, notes, writing, research, pdf |
| Browsing | safari, chrome, firefox, arc, reddit, youtube |

## Rules
1. ALL ML processing must happen on-device — no network calls
2. Use NLTagger for entity extraction
3. Keyword matching must be case-insensitive
4. Productivity analysis should be conservative
5. Combine app IDs, window titles, and URLs for accuracy
6. Calendar events take priority over app-based detection

## Data Flow
```
WindowMonitor → ContextAnalyzer → AIService → SpaceManager
                    ↓
        NLTagger + Core ML Models
                    ↓
        Context (mode, confidence, entities)
```
