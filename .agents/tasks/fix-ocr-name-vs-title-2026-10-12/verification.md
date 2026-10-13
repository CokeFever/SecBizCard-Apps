# Verification — Fix OCR Name-vs-Title (email cross-ref + title lexicon)

Date: 2026-10-12 (finalized 2026-10-13, review APPROVED)
Iteration: FINAL — `review.json` verdict = **APPROVED** (two non-blocking notes, see end)
Worktree / package: `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR`
Final commit on main: **97e45a5** (`fix(ocr): email-coverage name matcher + modern/abbrev title lexicon`)

## Email<->name matcher algorithm (`_emailNameCoverage`)

Pure, allocation-light function returning a 0.0–1.0 coverage score for how well
a candidate's Latin name tokens reconstruct the **personal** email local-part.
Bidirectional (candidate-vs-email and email-vs-candidate prefixes) to tolerate
OCR noise and numeric suffixes. Only runs when the mailbox is personal
(role mailboxes skipped) and `nameLen >= 2`.

Normalization: candidate tokens → alpha-only lowercase (initials like `A.`
collapse to `a`); local-part reduced to `eu` = `[a-z0-9]` and `euAlpha` =
alpha-only (strips digit suffixes, e.g. `joannetsai2` → `joannetsai`,
`earth80` → `earth`). Requires `euAlpha.length >= 2` and candidate 1–4 tokens.

Patterns handled, scored by strongest match:

- **1.0** — exact full-name reconstruction: `first.last`, `firstlast`,
  `last.first`, `lastfirst`, or all-tokens-joined (covers middle names).
- **0.9** — prefix match of any full-name form (tolerates a trailing stray OCR
  char / truncation on either side).
- **0.75** — initial patterns `flast` (`fi+last`) or `firstl` (`first+li`),
  exact or prefix.
- **0.5** — a single first OR last (len ≥ 3) present as a prefix OR anywhere via
  `euAlpha.contains(...)` (so a two-initial local-part like `sachen` =
  `s`+`a`+`chen` still credits the surname `chen` mid-string).
- **0.0** — no usable match.

Scoring hooks in `_scoreNameCandidate`:
- coverage > 0 → `score += coverage * emailNameBoost(80)` (1.0 → +80, beats the
  +45 Latin structure bonus; 0.75 → +60; 0.5 → +40).
- coverage == 0 AND the line got the +45 Latin structure bonus AND a title
  anchor is within 3 line-heights → **demotion** `emailNameMismatchPenalty(-50)`
  (the job-title line that reconstructs no personal local-part). A real name
  always has coverage > 0 so it is never demoted.
- Personal-mailbox gate: `emailIsPersonal` = local-part len ≥ 2 and not in
  `_roleMailboxLocalParts` (separators stripped; `no-reply`/`no.reply` →
  `noreply`). Skips both boost and demotion for role mailboxes.

## Title lexicon added

**`_titleModifierWords` (pre-head modifier words) added:**
`solution`, `solutions`, `cloud`, `platform`, `customer`, `success`, `field`,
`site`, `reliability`, `growth`, `data`, `machine`, `learning`, `research`,
`development`, `infrastructure`, `security`, `quality`, `assurance`, `support`,
`distinguished`, `program`, `project`.

**English `k.title` head/role nouns added** (in `_getKeywordsForLanguage`):
`solution`, `platform`, `cloud`, `success`, `reliability`, `scientist`,
`strategist`, `evangelist`, `advocate`, `fellow`, `intern`, `trainee`, `rep`.

**`_titleAcronyms` (new set, stored lowercase):**
`sre`, `fde`, `tpm`, `em`, `swe`, `sde`, `sdet`, `qa`, `dba`, `ux`, `ui`,
`devops`, `mlops`, `vp`, `svp`, `evp`, `avp`, `ceo`, `cto`, `cfo`, `coo`, `cio`,
`cmo`, `ciso`, `cpo`, `cro`, `gm`, `md`, `pmm`, `bdm`, `csm`, `tam`, `hrbp`,
`pm`, `ai`, `ml`, `se`, `ae`, `r&d`.

**`_roleMailboxLocalParts` (new set, for the personal-mailbox gate):**
`info`, `sales`, `support`, `contact`, `hello`, `admin`, `office`, `hr`,
`service`, `enquiry`, `enquiries`, `marketing`, `team`, `mail`, `noreply`,
`help`, `jobs`, `careers`.

### Acronym false-positive guard chosen

Acronyms are treated as **corroboration-gated**, never hard name-penalizers on
their own, to protect real names like "Ai Nakamura" / "A.I. Smith":

- **Title-candidate tagging:** a line is tagged as a title via an acronym only
  when it is a single token that is entirely a `_titleAcronyms` member
  (`toks.length == 1 && _titleAcronyms.contains(toks.first)`). The 1-token
  requirement keeps a 2-word name out of the title bucket.
- **Pure-title penalty (-120):** an acronym counts toward the "every word is a
  title word" test ONLY if `acronymCorroborated` =
  `(words.length >= 2 && hasNonAcronymTitleWord) || nearTitleAnchor`. A lone
  uncorroborated acronym on a plausible name line does not trigger it.
- **Soft -30 (`acronymTitleSignal`):** applied only when a single-word line is a
  lone acronym AND a title anchor is adjacent — nudges a stray "SRE" below the
  name without hard-penalizing it.

Date: 2026-10-12
Worktree / package: `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR`

## Commands run (exact)

Flutter pinned 3.38.9 via fvm (matches CI pin), run from the package dir
`/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR`:

```
/Users/jack/fvm/bin/fvm spawn 3.38.9 test test/parsing_test.dart
/Users/jack/fvm/bin/fvm spawn 3.38.9 analyze
```

## Test results

- **Before any change (baseline):** `All tests passed!` — 47 tests.
- **After implementation + 9 new regression tests:** `All tests passed!` — 56 tests
  (47 original, all still green + 9 new).

New regression tests added to `test/parsing_test.dart` (inside the
`parseLines field assignment` group):

1. Microsoft card: `Joanne Tsai` / `Solution Engineer` / `joannetsait@microsoft.com`
   → `displayName == 'Joanne Tsai'`, not `Solution`, title contains `Solution Engineer`.
2. Microsoft card, flast email `jtsai@` → `Joanne Tsai`.
3. Microsoft card, firstl email `joannet@` → `Joanne Tsai`.
4. `David Chen` + bare `SRE` → `David Chen`, title contains `SRE`.
5. `Emily Wang` + bare `FDE` → `Emily Wang`.
6. `Michael Lee` + `Cloud Architect` → `Michael Lee`.
7. `Sarah Kim` + `Customer Success Manager` → `Sarah Kim`.
8. Role mailbox `info@acme.com`, `Peter Lin` + `Account Manager` → `Peter Lin`
   (email signal does NOT distort selection).
9. Acronym guard: `Ai Nakamura` (standalone) + `Product Manager` + `ainakamura@`
   → `Ai Nakamura` (the acronym `ai` is NOT penalized as a title).

### One existing test needed a scoring-balance fix (NOT weakened)

During implementation the "Named Account Manager" test (`Sally Chen 陳曉君`,
email `sachen@paloaltonetworks.com`) briefly regressed because the new
coverage matcher's single-name tier only did prefix matching, and `sachen`
carries the surname `chen` mid-string (leading initials `s` + `a`). Fixed by
letting the single first/last tier also match via `euAlpha.contains(...)` (not
only prefix) for tokens ≥ 3 chars — this restores and generalizes the old
`emailUser.contains(p)` behavior. **No assertion was weakened or deleted**; the
test asserts the same expected name and now passes.

## Analyze results

```
Analyzing SecBizCard_OCR...
   info • The package name 'SecBizCard_OCR' isn't a lower_case_with_underscores identifier • pubspec.yaml:1:7 • package_names
1 issue found.
```

- The single remaining `info` is the **pre-existing** `package_names` lint on
  `pubspec.yaml` — unrelated to this change.
- A `prefer_is_empty` lint that my edit surfaced (`words.length >= 1`) was fixed
  to `words.isNotEmpty`. **No new errors or warnings introduced.**

## Scope / safety confirmations

- **No change outside** `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR`
  except this verification note under `SecBizCard-Apps/.agents/tasks/...`.
  Files changed in the package:
  - `lib/src/secbizcard_ocr_impl.dart` (scoring logic + lexicon)
  - `test/parsing_test.dart` (new regression tests)
  - `CHANGELOG.md`
- **The `recognizeCard` Cloud Function was NOT touched.** No `functions/`,
  Firebase, backend, website, or geometric-crop code was modified. CLIENT-SIDE
  parsing only.
- **No app-version bump.** No `pubspec.yaml` version change in the app repo.
- **Release dependency:** this is a client-side parsing change with no backend /
  Remote Config component, so **no deploy is involved** — the fix reaches end
  users only when the app is rebuilt and released against the updated
  `SecBizCard_OCR` package.

## Design notes

- Shipped as **code-default constants** via the existing `_tune('key', default)`
  pattern (`emailNameBoost=80`, `emailNameMismatchPenalty=-50`,
  `acronymTitleSignal=-30`), forward-compatible with the remote-tuning map but
  with **no `parseLines(tuning:)` API change** — matches `pureTitleNamePenalty`.
- `"solutions"` was NOT moved out of the company keyword set; it was added to
  `_titleModifierWords` as well (a word may be in both), preserving company
  detection (AWS/Kantar tests stay green).
- Acronyms are gated: they only count toward pure-title with corroboration
  (another title/modifier word on a ≥2-word line, or an adjacent title anchor),
  protecting standalone-acronym real names.

## Review verdict (iteration FINAL)

`review.json` = **APPROVED**. Two non-blocking notes recorded for a future tune
(no code change required to ship):

1. The 0.5 single-name coverage tier yields +40, below the +45 Latin structure
   bonus. Harmless for the tested cases (competing titles take the -120
   pure-title penalty) but a title carrying only the structure bonus could
   theoretically win. Consider raising the single-name tier/multiplier later.
2. The demotion's `startsKnownSurname` guard reuses the CJK-only
   `_commonChineseSurnames` set against a Latin token, so it never fires on the
   Latin demotion path. Behavior is still correct (real Latin names have
   coverage > 0 and are never demoted), but the guard is effectively dead code.
   Optionally drop or replace with a Latin surname check in a future pass.

## Branch finalization

- Branch `fix/ocr-name-vs-title` rebased onto `main` — already based directly on
  `266c291`, so the rebase was a no-op ("up to date").
- `main` fast-forwarded `266c291..97e45a5` (`--ff-only`) from the main checkout
  `/Users/jack/_Projects/SecBizCard`. **Final commit on main: `97e45a5`.**
- NOT pushed to any remote. Worktree left in place (orchestrator removes it).
- No app-version bump. The fix reaches users only on the next app
  rebuild/release against the updated `SecBizCard_OCR` package.
