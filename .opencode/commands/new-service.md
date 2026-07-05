---
description: Create a new service file
---

Create a new service file in Sources/Services/ with proper structure.

```bash
touch Sources/Services/$ARGUMENTS.swift
```

Then generate the service with:
- actor or class with .shared singleton
- Logger for all output
- Swift 6 structured concurrency
- Follow existing patterns from SpaceManager.swift or AIService.swift
