---
description: Build universal binary for Intel and Apple Silicon
---

Build a universal binary that supports both Intel (x86_64) and Apple Silicon (arm64) architectures.

```bash
swift build -c release --arch arm64 --arch x86_64
```

Report the build output and binary location.
