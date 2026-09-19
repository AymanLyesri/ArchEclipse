# Supporter Profile Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show supporter badge + Since-date card in UserProfileWidget, with Donations upsell for members.

**Architecture:** Profile-local change only — extend supporter check to fetch `created_at`, cache in UserProfileState, render AppBadge + Card with Theme-only styling.

**Tech Stack:** Quickshell/QtQuick QML, Supabase REST via curl Process, Theme tokens.

**Spec:** `docs/superpowers/specs/2026-09-19-supporter-profile-design.md`

## Global Constraints

- Entitlement is read-only `public.supporters` row-presence — never write supporters from QML.
- Use `Theme` tokens only — never hardcode colors.
- `qmllint` touched files must pass (exit 0) before claiming done.
- Reload with SUPER+B and repro supporter / non-supporter / signed-out states.

## Review Focus

- Expired JWT during supporter check should refresh, not show Member incorrectly.
- Empty/missing `supporters` row must show Member upsell, not crash on null date.
- Signed-out must hide card entirely, not show upsell.
- CTA must land on Donations tab via `Registry.selectLeftTab("Donations")`.
- Cached `supporterSince` must survive LeftIsland destroy/recreate without refetch.

---

### Task 1: State + data (supporterSince plumbing)

**Files:**
- Modify: `services/UserProfileState.qml`
- Modify: `widgets/leftPanel/UserProfileWidget.qml:46-56,109-139,436-471`

**Interfaces:**
- Consumes: `supporters?select=id,created_at` REST rows.
- Produces: `root.supporterSince: string`, `UserProfileState.supporterSince: string`.

- [ ] **Step 1: Add cache field**

```qml
// services/UserProfileState.qml, after cachedEmail
property string supporterSince: ""
```

- [ ] **Step 2: Add widget property**

```qml
// UserProfileWidget root state, near _cachedEmail
property string supporterSince: ""
```

- [ ] **Step 3: Extend save/restore**

```qml
// saveToCache(): add
UserProfileState.supporterSince = root.supporterSince;
// restoreFromCache(): add
root.supporterSince = UserProfileState.supporterSince;
```

- [ ] **Step 4: Extend supporter query**

```qml
// checkSupporter(): change select=id to select=id,created_at
p.command = ["bash", "-c", "curl -sS -H 'apikey: " + supabaseKey + "' -H 'Authorization: Bearer " + session.access_token + "' '" + supabaseUrl + "/rest/v1/supporters?select=id,created_at&id=eq." + encodeURIComponent(uid) + "'"];
```

- [ ] **Step 5: Parse created_at**

```qml
// onSupporterChecked(): after supported const
const since = (supported && rows[0]?.created_at) ? rows[0].created_at : "";
root.supporterSince = since;
// include supporterSince in profile rebuild + saveToCache path; clear on logout()
```

- [ ] **Step 6: Verify**

Run: `qmllint services/UserProfileState.qml widgets/leftPanel/UserProfileWidget.qml`
Expected: exit 0 (modulo pre-existing `?.` env-255 baseline).

### Task 2: UI (badge + status card)

**Files:**
- Modify: `widgets/leftPanel/UserProfileWidget.qml:847-892,1018-1052`

**Interfaces:**
- Consumes: `root.profile.is_supporter`, `root.supporterSince`, `Registry.selectLeftTab`.
- Produces: visual badge + Card (no new exports).

- [ ] **Step 1: Identity badge**

```qml
// Replace Supporter Label in Flow (:1031-1035) with:
AppBadge {
    text: root.profile?.is_supporter === true ? "Supporter" : root.profile?.is_supporter === false ? "Member" : "…"
    color: root.profile?.is_supporter === true ? Theme.accent : Theme.muted
}
```

- [ ] **Step 2: Status card under identity**

```qml
// After identity Rectangle (ends :1052), before Update/Refresh/Logout Row:
Card {
    width: parent.width
    visible: !!root.profile
    Label { text: root.profile?.is_supporter === true ? "Supporter active" : "Member"; font.bold: true; color: Theme.fg }
    Label { text: root.profile?.is_supporter === true ? ("Since " + root.formatTs(root.supporterSince)) : "Support the project to unlock Supporter status"; color: Theme.fgDim; wrapMode: Text.WordWrap; width: parent.width }
    AppButton {
        width: parent.width
        text: root.profile?.is_supporter === true ? "View Donations" : "Become supporter"
        onClicked: Registry.selectLeftTab("Donations")
    }
}
```

- [ ] **Step 3: Minimal view badge**

```qml
// minimalView Column after username Text (:882-891):
AppBadge {
    visible: root.profile?.is_supporter === true
    text: "Supporter"
    color: Theme.accent
    anchors.horizontalCenter: parent.horizontalCenter
}
```

Note: Column has no anchors for centering child — use `x: (parent.width - width) / 2` like avatar above.

- [ ] **Step 4: Verify**

Run: `qmllint widgets/leftPanel/UserProfileWidget.qml`
Expected: exit 0. Reload SUPER+B: supporter sees gold badge + Since date; member sees Member + upsell; signed-out hides card; CTA opens Donations.
