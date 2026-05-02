# AI Usage Log

| Date | Tool | Prompt Summary | Output Used | Learning Reflection |
|---|---|---|---|---|
| 2026-03-08 | ChatGPT/Codex | Scaffold Firebase-ready Flutter project and dependency setup (Phase 1) | Partially used after manual dependency/version review | Learned to treat generated setup as a baseline, then validate every package/API version manually. |
| 2026-03-09 | ChatGPT/Codex | Draft Firestore schema markdown + rules strategy | Used with manual edits for assignment-specific policy requirements | Learned to map business rules to Firestore rule expressions before writing UI code. |
| 2026-03-12 | ChatGPT/Codex | Generate model classes with fromMap/toMap/copyWith patterns | Fully used, then tested in app runtime | Learned consistency in serialization patterns reduces downstream bugs. |
| 2026-03-18 | ChatGPT/Codex | Build auth service/provider with FCM token sync | Used after adding custom error handling and lifecycle fixes | Learned stream/state ownership boundaries between provider and service layer. |
| 2026-03-19 | ChatGPT/Codex | Build login/register forms with validation and loading UI | Used with styling and navigation adjustments | Learned to verify async button disable states to prevent duplicate requests. |
| 2026-03-24 | ChatGPT/Codex | Implement profile screen + reusable avatar widget | Used with local style refactor | Learned reusable widgets simplify consistent UX across tabs. |
| 2026-03-30 | ChatGPT/Codex | Implement session CRUD/streams in FirestoreService (Phase 3) | Used with transaction and query tweaks | Learned when to use streams vs one-shot futures in collaboration apps. |
| 2026-04-02 | ChatGPT/Codex | Build playlist host/collaborator UI and vote interactions | Used with custom animation and optimistic state tuning | Learned UI feedback timing matters for perceived real-time quality. |
| 2026-04-07 | ChatGPT/Codex | Create Cloud Functions Spotify integration and callable handlers | Used with secret/config hardening | Learned credentials must stay server-side and never in client binaries. |
| 2026-04-10 | ChatGPT/Codex | Add mood tags + recommendation mapping strategy | Used after manual genre mapping adjustments | Learned to keep mapping logic explainable for demo Q&A. |
| 2026-04-15 | ChatGPT/Codex | Build chat real-time stream + emoji reaction UX | Used with long-press behavior refinements | Learned reaction updates are simplest as single nullable fields for first release. |
| 2026-04-20 | ChatGPT/Codex | Add push-notification trigger flow and profile stats queries | Used with Firebase Console verification | Learned to cross-check Cloud Function side effects directly in console logs. |
| 2026-04-26 | ChatGPT/Codex | Implement settings/account safety flows and app info polish | Used with re-auth prompt and preferences persistence | Learned destructive account operations need explicit confirmation and recovery paths. |
| 2026-04-28 | ChatGPT/Codex | Draft README + architecture decisions docs for grading rubric | Used with team-specific details and edits | Learned technical writing quality is as important as code for final grading. |

All AI-generated or AI-assisted output was reviewed, tested, and understood before commit. Firebase reads/writes, authentication behavior, and function-side effects were validated against the Firestore Console and Firebase Authentication dashboard during implementation and QA.
