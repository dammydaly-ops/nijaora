# Nijaora PRD v1.3 — Review

**Reviewer stance:** buildable, but several requirements are underspecified in ways that will cause rework or trust problems after launch. Severity: 🔴 blocking, 🟠 fix before pilot, 🟡 clarify/polish.

## What is strong

- The core insight is sharp: **area-first discovery without GPS** is a genuine differentiator in Nigeria, and "customer chooses the area, business declares its area" is a clean rule that produces a testable matching model.
- Scope discipline is unusually good for a v1. Explicit non-goals, Phase 2 gated on evidence, no payments, no cart.
- Trust design is better than most marketplaces: reviews tied to conversations, public score formula, verified badge reserved for admin verification.
- Supply-side plan is realistic. Ambassadors, QR codes, and a 5-minute onboarding flow acknowledge that marketplaces die on the supply side.
- Location data as versioned reference data with stable IDs is the right call and avoids the free-text trap.

## 🔴 Blocking issues

### 1. "Verified-by-conversation" is not yet a trust guarantee
As written, a single "hi" message unlocks a 5-star review. Collusion is trivial (a friend sends one message).

**Fix before build:** define review eligibility server-side as all of:
- at least 1 customer message **and** at least 1 business reply,
- conversation at least 24 hours old (or 3+ messages each way),
- no blocked/reported state, no prior review by that customer for that business,
- rate limit: 1 review per customer per business, ever; 3 reviews per customer per 30 days.

Also store `reviewEligibility` evidence (message counts, first/last message timestamps) so admin can audit a suspicious review. Without this, your main differentiator is a badge anyone can farm.

### 2. Ranking is not computable
Section 5.6 lists five factors with no weights, and "profile completeness" / "keyword relevance" / "rating once enough reviews exist" are undefined. Two engineers will build two different rankings, and neither is testable.

**Fix:** publish a deterministic scoring formula with weights, normalisation, and tie-breakers, e.g.

```
score = 0.40 * relevance + 0.20 * areaMatch + 0.15 * completeness
      + 0.15 * responseScore + 0.10 * ratingScore
tie-breakers: responseScore, reviewCount, publishedAt desc
```
Document that `ratingScore = 0` below 5 reviews and renormalise. Add acceptance criteria with fixture businesses proving order. Keep ranking and verification explicitly separate in code (never derive badge from score).

### 3. "Nearby LGAs" needs data you have not planned for
Section 5.3 shows businesses from neighbouring LGAs, but the location dataset in 5.9 has no adjacency field and no coordinates. You cannot compute "nearby" from `parentId` alone.

**Fix:** add `adjacentIds` (or centroid lat/lng + radius) to the LGA records and treat adjacency as curated, versioned data. Also decide: does "nearby" respect mobile providers' declared areas only? It should.

### 4. Search architecture is deferred past the point of no return
Firestore cannot do `serviceAreaLgaIds array-contains lgaId` **plus** category filter **plus** sort by rank **plus** pagination. You will end up doing client-side ranking over over-fetched pages, which breaks pagination and cost targets.

**Fix now, in Phase 0:** pick the hosted index (Typesense or Algolia) and design the sync. My recommendation is **Typesense** (cheap, self-hostable on Cloud Run, good typo tolerance, supports geo + facet + custom ranking). Treat Firestore as source of truth; Cloud Functions write to the index on publish/update/delete; nightly full rebuild. Do not build the "synonym-mapped Firestore" fallback — it will be thrown away.

### 5. Admin actions must not be client writes
Section 6.16 wants an immutable audit log, but if admins write `adminAuditLogs` (or hide businesses) directly from the client, a compromised admin token can forge or skip entries.

**Fix:** every admin mutation goes through a **callable Cloud Function** that checks a custom claim (`admin`/`moderator`), writes the change and the audit log in one transaction, and is the only writer to `adminAuditLogs`. Require 2FA (TOTP) for admin accounts. Add per-action "reason" as mandatory.

### 6. NDPA compliance is one bullet; it is actually a workstream
Launching in Nigeria means: NDPC registration as a data controller (depending on data volume/level), lawful basis + consent language per purpose, DPO/contact, cross-border transfer mechanism for Firebase (US), retention schedule, and a public deletion route. Google Play additionally requires an **in-app deletion request and a web deletion URL**.

**Fix:** assign an owner and budget in Phase 0. Add to scope: privacy policy, terms, data-processing inventory, deletion implementation (Cloud Function cascade across Firestore + Storage + Auth + search index), and the Play data-safety form. Budget for a lawyer; this is not a template exercise.

## 🟠 Fix before pilot

| # | Issue | Impact | Recommendation |
|---|---|---|---|
| 7 | OTP is the whole front door, and SMS in Nigeria is unreliable/expensive | Sign-up drop-off, cost blowout, SIM-swap abuse | Evaluate Termii/Africa's Talking with a custom token flow, **or** keep Firebase Auth but add fallback channel + per-phone/per-IP/per-device rate limits. Build an OTP cost dashboard. Never allow unlimited resends. |
| 8 | Light score mixes trust, activity, and marketing | Gameable (fill profile, get "Shining"), and rating weight conflicts with "once enough reviews" | Make the band a **trust** signal: completeness 20, response 25, reviews 25 (0 until 5 reviews), phone 10, admin verification 20; renormalise and version the formula (`scoreVersion`). Show the checklist, not just the band. |
| 9 | No report SLA or moderator staffing plan | Reports rot, users lose trust, app-store complaints | Define SLA (e.g., 24h for safety, 72h for listing), escalation, and who is on call. Add `report.status` transitions to the audit log. |
| 10 | WhatsApp taps are the only measurable outcome | You will not know if business actually happened | Keep click tracking, but add a 1-tap "Did you hire them?" follow-up in-app and a review prompt after 48h. Otherwise the funnel ends at a click. |
| 11 | No image moderation | Illegal/abusive/CSAM risk, app-store removal risk | Add automated image moderation (Cloud Vision SafeSearch or a provider) on portfolio/listing/chat uploads, plus a human queue for flagged items. |
| 12 | Account deletion is one line | Play/NDPA non-compliance, orphaned messages | Specify cascade: anonymise user, keep reviews (tombstone `deletedUser`), delete/retain messages per §9, delete Storage objects and FCM tokens, remove from search index. |
| 13 | OTP/session abuse controls are vague | SMS pumping, spam chats | Add App Check, device attestation on Android, per-IP/IP+phone limits, new-chat cap (e.g., 10/day), and CAPTCHA on web sign-in. |
| 14 | Public slug collisions and renames | Broken QR codes and links | Reserve slugs, enforce uniqueness, keep `slugHistory` with 301s, never reuse. QR should encode the canonical URL. |
| 15 | "Notify me when someone joins" collects contact data | Privacy + channel cost | Collect phone/email with explicit consent, or use push-only with an in-app subscription record. Define expiry (e.g., 90 days). |
| 16 | Guests can browse but "weekly active customers" needs identity | Metric is uncomputable/inflated | Track anonymous `deviceId` (rotating, disclosed) for search analytics, and define WAC as signed-in users who searched or messaged. Say it explicitly. |

## 🟡 Clarify or accept the trade-off

- **Chat model:** one conversation per (customer, business) with listing context attached, *not* per listing. Otherwise inboxes explode and reviews become ambiguous. Confirm this before schema work.
- **Unread counts:** denormalised counters on `conversations` must be updated in transactions; a client-side count over messages will be slow and expensive. Budget Firestore reads per chat open.
- **Message retention vs deletion:** if either party deletes, what does the other see? Recommend "deleted for you" locally + server-side purge on account deletion, not immediate mutual destruction.
- **Blocking:** blocking should stop new messages both ways and hide the thread; define whether it also removes existing reviews.
- **Phone numbers allowed in chat:** fine, but add a scam warning when a message contains a phone number + "pay"/"deposit", and log the event.
- **Verification levels:** "location confirmed" by shop photo is weak (any shop). Consider requiring the photo to include a handwritten code/date, or ambassador geo-stamped visit. Identity verification via NIN slip is sensitive data — store encrypted, restrict access, delete after decision (already stated — enforce in Storage rules too).
- **Ambassadors cannot verify their own registrations:** good. Add fraud detection (same device, same photo reused, burst registrations) and pay only on 30-day retention.
- **Phase numbering:** §14 uses Phase 1–4 while §10 calls post-MVP "Phase 2". Rename to `Stage 0–4` and `Post-MVP` to avoid roadmap confusion.
- **SLOs:** "usable within a few seconds" is not testable. Set: search first results ≤ 2.5s p75 on 3G-class connection, cold start ≤ 4s, chat send optimistic ≤ 100ms.
- **Web SEO pages:** serving separate SSR pages means a second rendering stack. Either commit to Next.js for public pages in Phase 2 or remove SEO from v1 claims; QR/share links should still work.
- **Admin console on web:** Flutter web for internal admin is acceptable (no SEO need), but it doubles the surface area. For a small team, a thin Next.js/React admin is often faster to build and easier to lock down. Decide in Phase 0.
- **Push reliability:** FCM on Android without Play Services (some devices) and on web is best-effort. For verification outcomes, add SMS/in-app fallback so critical notices are never lost.

## Missing requirements to add

1. **Abuse/fraud:** photo pHash duplicate detection (not just "repeated identical photos" — perceptual hashing), device/fingerprint signals (carefully, under NDPA), velocity limits on registration, and a scam-pattern review queue.
2. **Rate limits:** OTP, new chats, reviews, reports, profile edits — with concrete numbers and error copy.
3. **Moderation UX:** what the reported user sees, appeal path, and evidence snapshot (content may be deleted later — store a copy for the case).
4. **Business owner onboarding for low literacy:** voice-guided setup, Pidgin copy, "call an ambassador" button, and the ability to finish later (draft persistence is mentioned but not specified).
5. **Opening hours / availability semantics:** timezone (Africa/Lagos), holidays, "Available today" rollover at midnight, per-listing overrides.
6. **Offline drafts:** what is stored locally, for how long, and how conflicts resolve.
7. **Search quality operations:** zero-result query log, synonym management UI, and a weekly review ritual.
8. **Analytics governance:** event schema versioning, PII scrubbing, and a retention period.
9. **Legal content:** prohibited-items list, DMCA-style takedown, and Nigerian consumer-protection language.
10. **Support:** in-app help, contact channel, and response promise (users will ask "is this business real?").

## Answers to §16 open decisions (recommendation)

1. **Pilot:** one state first. **Lagos: Ikeja, Surulere, Eti-Osa** (dense, mixed services/products, team can visit). Add **Oyo: Ibadan North** only after Lagos coverage targets are met. Two states at launch doubles ambassador and moderation cost for little learning.
2. **Categories (5):** tailoring/fashion (service + product), plumbing, electrical, carpentry, hair & makeup. Add "phone/electronics repair" only if pilot interviews show demand; it is a different trust model.
3. **Search:** Typesense, synced from Firestore by Cloud Functions, with a nightly rebuild and a `/health` check comparing counts. Avoid Algolia's per-search pricing at scale; avoid hand-rolled Firestore search.
4. **Light score:** remove rating weight until 5 reviews; renormalise; publish bands (Starting 0–39, Growing 40–69, Shining 70–100) and a versioned formula. Show component breakdown to owners, band only to customers.
5. **Verification:** Level 2 = ambassador geo-stamped visit **or** shop photo with a Nijaora-issued code visible. Level 3 = government ID + selfie, manually reviewed, stored encrypted, deleted 30 days after decision. Do not claim "identity verified" beyond what was checked.
6. **Ambassadors:** stipend per completed profile + bonus at 30-day activity, capped; recruit per cluster; no verification rights; monthly quality review with a 5% audit sample.
7. **Pidgin:** after pilot. Ship plain English with Pidgin-friendly phrasing; build i18n plumbing now (all strings in ARB files) so Pidgin is a translation, not a refactor.

## Suggested PRD patch (v1.4)

- Add `adjacentIds` to location data and a "nearby" definition.
- Add review eligibility thresholds and anti-collusion rules.
- Add the ranking formula and tie-breakers to §5.6.
- Commit to a search backend in Phase 0 instead of "one of".
- Add admin 2FA and callable-only admin writes.
- Add NDPA workstream, deletion cascade, and Play data-safety requirements.
- Define SLOs and report SLAs.
- Rename phases to Stage 0–4 + Post-MVP.
- Add moderation/abuse, rate-limit, and image-moderation requirements.
- Define guest analytics identity and WAC.
