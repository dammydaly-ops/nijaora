# Nijaora — App architecture & build plan

## 1. Stack decisions

| Concern | Choice | Why |
|---|---|---|
| UI | Flutter 3.47 (Android + web) | PRD requirement; one codebase for pilot |
| State | Riverpod (`flutter_riverpod`) | Testable, no BuildContext coupling, easy overrides in tests |
| Navigation | `go_router` | Declarative, deep links (`/b/:slug`), auth redirects in one place |
| Backend | Firebase (Auth, Firestore, Storage, FCM, Functions) | PRD requirement; managed ops for a small team |
| Search | Typesense (Phase 0 decision) | Firestore cannot do area + category + rank + pagination. Interface is repository-based so it can be swapped |
| Local cache | `shared_preferences` (selected area, onboarding flags) | Small, sufficient for v1 |
| Money/date | `intl` | ₦ formatting, Africa/Lagos time |

**Auth is behind an interface.** The app runs today with an in-memory fake (`AUTH_BACKEND=demo`, the default) and switches to Firebase with `--dart-define=AUTH_BACKEND=firebase` once a Firebase project exists. This lets UI work proceed without credentials and keeps tests hermetic.

## 2. Folder structure

```
lib/
  main.dart                     # entrypoint only
  app/
    app.dart                    # MaterialApp.router, theme, locale
    bootstrap.dart              # Firebase init + ProviderScope startup
    router/app_router.dart      # routes, guards, redirects
    theme/
      app_colors.dart           # brand tokens (ink, amber, cream)
      app_theme.dart            # Material 3 themes, typography, inputs
      app_spacing.dart
  core/
    config/app_config.dart      # dart-define flags (backend, env)
    errors/app_failure.dart     # typed failures -> user-facing copy
    utils/                      # formatters, validators, paging
    services/                   # analytics, prefs, whatsapp, notifications
    widgets/                    # shared UI: empty/error/loading, chips, badges
  data/
    models/                     # immutable models + fromJson/toJson
    demo/demo_catalog.dart      # seed location + business data for demo mode
    repositories/
      *.dart                    # abstract interfaces
      demo/                     # in-memory implementations
      firebase/                 # Firebase implementations (guarded)
    sources/
      firebase/firebase_options.dart  # placeholder until `flutterfire configure`
  features/
    auth/presentation/          # splash, welcome, phone, OTP
    location/                   # area picker sheet + selection provider
    discovery/presentation/     # home, search results, filters, sort
    business/presentation/      # public profile, portfolio, trust panel
    chat/presentation/          # inbox + thread (optimistic send states)
    registration/presentation/  # business onboarding wizard + validation
    account/presentation/       # settings, role switch, sign out
```

**Rule:** features never import another feature's `presentation`. Shared UI lives in `core/widgets`; shared data lives in `data`. Repositories are the only place that knows about Firebase.

## 3. Data flow

```
UI (widget) → Riverpod provider → repository interface → demo | Firebase
                                    ↑
                            Firestore / Typesense
```

- Providers expose `AsyncValue` so every screen gets loading / error / data states by construction.
- Search criteria is one immutable `SearchQuery` object; results are a `SearchPage`.
- Area selection is a single provider persisted to `shared_preferences`; changing state invalidates the LGA (PRD 5.2).

## 4. Location model

```dart
LocationNode(
  id: 'ng-la-ikeja',        // stable, never reused
  type: LocationType.lga,
  parentId: 'ng-la',        // state
  name: 'Ikeja',
  aliases: ['Ikeja LGA'],
  adjacentIds: ['ng-la-oshodi', 'ng-la-agege'], // needed for "Nearby"
  status: active,
  datasetVersion: '2026.10.1',
)
```

`LocationRepository.validatePair(stateId, lgaId)` is used by both the picker and business registration. The same validation runs in Cloud Functions on publish (server is the authority).

Demo dataset: all 37 states/FCT, full LGAs for Lagos (20), FCT (6) and Oyo (33), curated neighbourhoods for pilot LGAs, adjacency for the pilot zone. A production dataset replaces the demo list without touching UI code.

## 5. Discovery rules implemented

- Fixed-location business matches its **base LGA** (and state-wide search matches any LGA in the state).
- Mobile provider matches any LGA in `serviceAreaLgaIds`; never its base unless declared (base is auto-declared by registration, per product decision — see note below).
- Whole-state search ignores LGA but keeps category/keyword.
- Thin results: exact matches → adjacent LGAs labelled "Nearby" → "Search the whole state" → "Notify me".
- Ranking is a deterministic function in `lib/data/search/search_engine.dart`, used by both demo and (later) server-owned sort; it is documented and unit-tested:

```
0.40 relevance + 0.20 area + 0.15 completeness + 0.15 response + 0.10 rating
```

## 6. Firebase setup (when available)

1. `flutterfire configure --project=<project> --platforms=android,web` (replaces the placeholder `firebase_options.dart`).
2. Enable Phone auth, Firestore, Storage, FCM in the console. Add Android SHA-1/SHA-256.
3. Deploy rules and indexes from `firebase/` (`firebase/README.md` has the commands).
4. Implement `FirebaseAuthRepository` (already stubbed) against real phone auth; the demo repository stays for tests.
5. Run with `flutter run --dart-define=AUTH_BACKEND=firebase`.
6. Admin writes go through callable Functions only; `adminAuditLogs` is deny-all on the client.

**Important:** phone OTP via Firebase has delivery and quota limitations in Nigeria. Track OTP success rate per network from day one; keep a commercial SMS provider (Termii/Africa's Talking) as a documented fallback.

## 7. Security rules (included)

`firebase/firestore.rules` enforces:
- published business profiles readable by anyone; drafts/private fields owner-only;
- listings writable only by the owning business;
- conversations/messages readable only by the two participants;
- reviews created only via callable validation (client create denied);
- reports creatable by signed-in users, readable by admins;
- notifications recipient-only;
- `adminAuditLogs` no client access.

`firebase/storage.rules` limits uploads to image content types, 5 MB, and owner-scoped paths.

## 8. What is built in this foundation

- Brand theme (amber "inner light" on ink/cream), responsive shell for phone and desktop widths.
- Phone + OTP sign-in (demo code `123456`), role selection, session persistence, sign-out.
- Home: location chip, search bar, category tiles, "Popular in your area" results, loading/empty/offline states.
- Area picker: state → LGA → neighbourhood, whole-state option, remembers last choice, state change clears LGA.
- Search: keyword + category + area, filters (type, availability, verified, rating), sort, pagination (20/page), skeletons, empty-state recovery (nearby / whole state / notify).
- Business profile: cover, badges, trust signals (verified phone, response time, reviews, light score band), portfolio, listings, reviews, Chat + WhatsApp (deep link + tap tracking stub).
- Chat: inbox and thread with listing context card, optimistic sending/sent/failed states, demo replies.
- Business registration wizard with the PRD's publish validations and plain-language error messages (demo publish; no photo picker yet).
- Tests: location pair validation, area matching, ranking, validation copy, and an app boot smoke test.

## 9. Deliberately not built yet

Firebase wiring against a live project (the code path and rules exist but need credentials), real photo upload/compression, FCM, Typesense sync, admin console, reviews submission UI (read-only demo), SEO pages, moderation queues. These need project credentials or backend work; the interfaces are in place.

## 10. Next steps (suggested order)

1. Firebase project + `flutterfire configure`; implement `FirebaseAuthRepository`; verify OTP on Android and web.
2. Business registration writes to Firestore with server-side validation callable.
3. Image pipeline (compress → Storage → thumbnails) and image moderation hook.
4. Typesense index + Cloud Function sync; swap `SearchRepository`.
5. Review eligibility callable + light score job.
6. Chat writes, unread transactions, FCM.
7. Admin console (Next.js or Flutter web) with 2FA and callable actions.
8. Pilot onboarding + instrumented funnel.
