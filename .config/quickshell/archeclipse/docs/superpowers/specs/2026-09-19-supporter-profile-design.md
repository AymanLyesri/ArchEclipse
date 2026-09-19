# Supporter Profile Overhaul — Design (2026-09-19)

Approved approach: **A — Profile-local card**.

## 1. Intent

- `lyesri99@gmail.com` added to `public.supporters` (manual admin grant, verified 2026-09-19 — both `lyesri22` + `lyesri99` now `is_supporter: true`).
- `lyesri22@gmail.com` confirmed supporter since `2026-08-25`.
- Overhaul `UserProfileWidget` so supporters get visible recognition + status, non-supporters get an upsell — without touching entitlement logic.

## 2. Architecture

- Scope: `widgets/leftPanel/UserProfileWidget.qml` only (+ `services/UserProfileState.qml` cache field).
- Navigation: existing `Registry.selectLeftTab("Donations")` (`services/Registry.qml:48-53`, `LeftIsland.qml:56` tabOrder includes `Donations`).
- Styling: `Theme` tokens only (`accent`, `accentFg`, `cardRadius` 8 — `theme/Theme.qml:48-64`). No hardcoded colors.
- No new tables, no RLS/migration, no trigger changes. Entitlement stays read-only row-presence in `public.supporters`.

## 3. Components

- Identity `Flow` (`UserProfileWidget.qml:1018-1036`): replace/augment `Supporter: Yes/No/…` label with gold `AppBadge` (`Supporter` / `Member` / `…` loading). Keep masked email.
- Minimal view (`:847-892`): append small `Supporter` badge under username when `is_supporter === true`.
- New status card under identity card: shared `Card` (12/8 margins):
  - Supporter: `Supporter active` + `Since <date>` (from `supporters.created_at`) + `View Donations` button → `selectLeftTab("Donations")`.
  - Non-supporter: `Member` + `Support the project to unlock Supporter status` + `Become supporter` button → same target.
  - Signed-out / unknown (`is_supporter === null`): hide card (current `…` fallback preserved in badge).

## 4. Data flow

- Extend `checkSupporter()` (`:436-444`) query: `select=id,created_at&id=eq.<uid>` (was `select=id`).
- Extend `onSupporterChecked()` (`:445-471`): parse `created_at`, set `profile.is_supporter` + `root.supporterSince` (ISO string or `""`), `saveToCache()`.
- `UserProfileState`: add `property string supporterSince: ""`; include in `saveToCache()` / `restoreFromCache()` (`:109-139`).
- `supporterLabel()` unchanged for progress text; new `formatSince()` reuses `formatTs()` (`:622-630`).
- Donations link: `Registry.selectLeftTab("Donations")` — requires `import qs.services` (already present).

## 5. Error handling

- Supporter fetch fail / non-array / empty while signed-in: keep current behavior — badge shows `…` or last cached value, card hidden, no error toast (matches `onSupporterChecked` early-return).
- Auth expiry (`isAuthErrorText`): existing `doRefresh("profile")` path reused.
- Never write `supporters` from QML — read-only REST, consistent with `docs/supporter-payments.md`.
- QML pitfalls: inner widths from explicit Flickable width (not `parent.width` of viewport), no `ListView` in `Flickable`, badge must be wheel-transparent.

## 6. Testing

- `qmllint` touched files must pass (exit 0).
- SUPER+B reload + repro: signed-in supporter (`lyesri99@gmail.com`) sees badge + Since date; signed-in non-supporter sees Member + upsell; signed-out sees no card; click CTA lands on Donations tab; close/reopen preserves via `UserProfileState` cache.
- Live DB already verified: both emails `is_supporter: true`.

## 7. Out of scope

- Payment history totals, tiers, supporter-only settings/perks, shared `SupporterBadge` reuse, DonationsWidget changes, island rail changes.
