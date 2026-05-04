# AI Usage Log

| Date | Tool | Prompt Summary | Output Used | Learning Reflection |
|---|---|---|---|---|
| 2026-04-07 | ChatGPT | Asked how to structure a Firebase Cloud Functions TypeScript project to call a third-party API without exposing credentials in the client app | Used as a conceptual reference; wrote the actual function logic manually | Learned that defineSecret is the correct approach for secrets in Functions v2, not functions.config() |
| 2026-04-15 | ChatGPT | Asked for an explanation of Firestore runTransaction vs a plain document update for concurrent writes | Used to understand the concept; implemented the transaction independently | Learned that transactions retry on contention, which is essential for vote correctness |
| 2026-04-26 | ChatGPT | Asked how Flutter's Provider notifyListeners interacts with widget lifecycle during navigation transitions | Used to understand the root cause of a crash; fixed the code ourselves | Learned that a widget still registered as a Provider dependent must not receive notifyListeners after it begins unmounting |

All AI-generated or AI-assisted output was reviewed and understood before use. All code was written, tested, and committed by Goo Choi and Eva Park.
