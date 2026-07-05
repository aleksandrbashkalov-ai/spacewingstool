---
description: Watch app logs in real-time
---

Stream app logs in real-time using the system log command.

```bash
log stream --predicate 'subsystem == "com.spacewingstool"' --level debug
```

This will show all debug output from the Spacewingstool app. Press Ctrl+C to stop.
