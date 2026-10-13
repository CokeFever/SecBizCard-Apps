# Implementation Plan — Fix OCR Name-vs-Title (email cross-ref + title lexicon)

## Context & ground truth (verified by reading the code)

- Target file (ALL changes live here): `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR/lib/src/secbizcard_ocr_impl.dart`
- Target method: `_scoreName(...)` (starts ~line 621) plus its two static keyword sources:
  - `_titleModifierWords` static set (~line 1032)
  - `_getKeywordsForLanguage(...)` which builds `k.title` / `k.company` / `k.address` (English block ~line 1191; the `k.title.addAll([...])` English list is where head/role title words live).
- `emailUser` (email local-part, lowercased, `@`-stripped) is already computed in `parseLines` at ~line 322 BEFORE the scoring loop and passed into `_scoreName` as a param — no plumbing change needed.
- Test harness: `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR/test/parsing_test.dart` (47 tests, confirmed ALL PASSING on this worktree).
- Verified test command (fvm 3.38.9 is installed, matches the CI pin): run from the package dir
  `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR`:
  `/Users/jack/fvm/bin/fvm spawn 3.38.9 test test/parsing_test.dart`
- SCOPE GUARD: CLIENT-SIDE parsing only. Do NOT touch `functions/`, `recognizeCard`, any Firebase/backend code, the website, or the `SecBizCard-Apps` repo. Do NOT touch the geometric crop scorer (`OpenCVProcessor.kt` / `AppDelegate.swift` / `docs/card_detection_scoring.md`) — that is the user's separate "problem 1" (crop), explicitly out of scope here.

### Why "Solution Engineer" wins today (root cause, confirmed in code)
1. The `-120` pure-title penalty (line ~750, `_tune('pureTitleNamePenalty', -120)`) only fires when `words.every((w) => keywords.title.contains(w) || _titleModifierWords.contains(w))`. "engineer" is in `k.title` but "solution" is in NEITHER `k.title` NOR `_titleModifierWords` (only plural "solutions" exists, and only as a *company* keyword). So "Solution Engineer" misses `-120`, takes only the small `-30` title-signal (line ~740), and keeps the `+45` Latin "2–4 capitalized words" structure bonus (line ~857) → it out-scores the real name.
2. The email↔name boost (lines ~877–880) is weak: `+30`, one-directional (boost only), whole-word-substring only (`emailUser.contains(p)` — misses `jtsai@`, `joannet@`, concatenations), and smaller than the `+45` title structure bonus.

### Design decisions (made here; rationale inline)
- **Ship code-default constants, NOT a tuning-API refactor.** The task explicitly permits this and warns against a large API change. New weights are added as `_tune('key', default)` calls so they are forward-compatible with the existing remote-tuning pattern (like `pureTitleNamePenalty`), but no `parseLines(tuning:)` plumbing is added. The existing `_tune` helper already returns the fallback when no map is supplied, so defaults ship in code with zero behavior risk.
- **Lexicon placement: use a dedicated title-modifier set, do NOT move "solutions" out of `k.company`.** Moving company words risks the company-detection tests (e.g. `AWS card` expects company detection; `enterprises/solutions` company keywords are load-bearing). New head/role words go into `k.title` (English block) and new modifier words into `_titleModifierWords`; new acronyms go into a new dedicated set gated into the title signal (see item 4).
- **Email signal is a RANKING adjustment only** — it boosts/demotes among OCR lines actually present; it never invents or forces a name that is not an OCR line (guard preserved by only ever adjusting an existing candidate's score).

---

## Plan

- [ ] 1. Add an email↔name coverage matcher helper and new weight constants.
      Add a private helper `double _emailNameCoverage(List<String> tokens, String emailUser)` (place it near `_scoreName`, e.g. just after it ~line 895) that returns a 0.0–1.0 score of how well a candidate's name tokens reconstruct the local-part. Algorithm:
      - Normalize: lowercase candidate tokens, strip non-`[a-z]` (drop initials dots/hyphens); drop tokens shorter than 1 char after cleaning. Lowercase+strip `emailUser` to `[a-z0-9]` → `eu`; also keep an alpha-only `euAlpha` (strip trailing/embedded digits like `joannetsai2`→`joannetsai`, `earth80`→`earth`). Require `tokens.length >= 1` and the candidate to be a Latin name candidate.
      - Build these reconstructions from the tokens (first = tokens.first, last = tokens.last; works for 2–4 word Latin names, use first and last only):
        * `first.last`, `firstlast`, `last.first`, `lastfirst`
        * `flast` (first-initial + last), `firstl` (first + last-initial)
        * `firstlastInitialRuns` — also try joining ALL tokens in order (handles middle names)
        * single `first`, single `last`
      - Match each candidate reconstruction against both `eu` and `euAlpha` (so `joannetsait@` with a trailing stray `t`, and `earth80@` numeric suffixes, still match via prefix). Scoring: return the STRONGEST match found:
        * exact equality of a full-name reconstruction (`first.last`/`firstlast`/`lastfirst`) → `1.0`
        * `eu`/`euAlpha` startsWith a full-name reconstruction, or reconstruction startsWith `euAlpha` (covers trailing OCR char / truncation) → `0.9`
        * `flast` / `firstl` exact or prefix match → `0.75`
        * single `first` or single `last` fully present as a prefix/whole token of `euAlpha` (len ≥ 3) → `0.5`
        * else `0.0`.
      - Keep it allocation-light and pure (no card state).
      Files: `.../lib/src/secbizcard_ocr_impl.dart`
      Verify: `/Users/jack/fvm/bin/fvm spawn 3.38.9 test test/parsing_test.dart` from the package dir — all 47 existing tests still pass (helper is unused until item 3, so this is a compile-green checkpoint).

- [ ] 2. Add a role-mailbox guard set and an `isRoleMailbox` check.
      Add a static `const Set<String> _roleMailboxLocalParts = { 'info','sales','support','contact','hello','admin','office','hr','service','enquiry','enquiries','marketing','team','mail','noreply','no-reply','help','jobs','careers' };` near the other static sets (~line 1032). In `_scoreName`, compute once near the top (after `emailUser` is in scope): `final emailIsPersonal = emailUser != null && emailUser.length >= 2 && !_roleMailboxLocalParts.contains(emailUser.replaceAll('-', '').replaceAll('.', ''));` (normalize `no-reply`/`no.reply` → `noreply`). This gates BOTH the new boost and the new demotion so a role address never distorts the name.
      Files: `.../lib/src/secbizcard_ocr_impl.dart`
      Verify: `fvm spawn 3.38.9 test test/parsing_test.dart` — all 47 still pass (gate not yet applied).

- [ ] 3. Replace the weak email boost with the coverage-based bidirectional email signal (PRIMARY FIX).
      Replace the current block at lines ~877–880 (the `+30` whole-word substring boost). New logic, applied only when `emailIsPersonal` and the candidate is a plausible name (`nameLen >= 2`, existing `p.length > 2`-style minimum preserved by requiring each matched token length > 2 OR a valid initial in a flast/firstl pattern):
      - Compute `coverage = _emailNameCoverage(candidateTokens, emailUser)` where `candidateTokens` is the Latin candidate split on whitespace (reuse the `words` split already computed for structure scoring).
      - BOOST: `score += coverage * _tune('emailNameBoost', 80)`. At `coverage=1.0` this is `+80`, comfortably beating the `+45` Latin title structure bonus and the proximity/height terms; at `0.75` (flast) it is `+60`, still decisive; at `0.5` `+40`. Chosen so any clear reconstruction overrides a competing pure-title line.
      - DEMOTION (new): when `emailIsPersonal` AND the candidate is a 2–4-word Latin line that got the `+45` structure bonus AND `coverage == 0.0` AND it does NOT start with/contain a known surname AND it is on or adjacent to a title anchor (reuse the existing title-proximity loop result — set a bool when a title anchor is within `maxHeight*3.0`): `score += _tune('emailNameMismatchPenalty', -50);`. Rationale: a name-shaped Latin line that reconstructs NONE of a known personal local-part, sitting by the title, is almost certainly the job title ("Solution Engineer") — this cancels its `+45` structure bonus and then some. Guard so a legitimate bilingual/CJK name or the real name (which WILL have coverage > 0) is never demoted.
      - Keep everything inside `_scoreName`; do not alter the setup block beyond item 2's additions.
      Files: `.../lib/src/secbizcard_ocr_impl.dart`
      Verify: `fvm spawn 3.38.9 test test/parsing_test.dart` — all 47 existing tests pass (the existing `swenlai@`/`Yvonne.Wang@`/`john.smith@` cases exercise the new matcher and must stay green). If any regress, tune weights (not rules) before proceeding.

- [ ] 4. Expand the title lexicon: head/role words, modifiers, and a gated acronym set.
      Three coordinated edits in the same file:
      (a) Add to the English `k.title.addAll([...])` list (~line 1191) the head/role words: `solution`, `platform`, `cloud`, `success`, `reliability`, `scientist`, `strategist`, `evangelist`, `advocate`, `fellow`, `intern`, `trainee`, `rep`. (Nouns that act as the title HEAD. "architect"/"analyst"/"consultant"/"specialist"/"associate"/"representative"/"engineer"/"developer"/"designer" already exist.)
      (b) Add to `_titleModifierWords` (~line 1032) the pre-head MODIFIER words used in multi-word titles so the pure-title `every(...)` check covers them: `solution`, `solutions`, `cloud`, `platform`, `customer`, `success`, `field`, `site`, `reliability`, `growth`, `data`, `machine`, `learning`, `research`, `development`, `operations` (already present), `infrastructure`, `security`, `quality`, `assurance`, `support`, `distinguished`, `program`, `project`. (Note: `account`, `senior`, `product`, `technical`, `sales`, `business`, `principal`, `staff`, `associate` already exist. Add `solutions` here even though it is also a company keyword — a word may be in both; the pure-title check reads `_titleModifierWords`, and `k.company` membership independently still contributes the `-80` company penalty, so "Solutions Architect" is covered without moving "solutions" out of `k.company`.) This makes "Solution Engineer", "Cloud Architect", "Platform Engineer", "Customer Success Manager", "Field Engineer", "Sales Engineer", "Solutions Architect", "Site Reliability Engineer", "Data Scientist" all resolve as pure-title (every word ∈ title∪modifier) → the `-120` penalty fires.
      (c) Add a NEW static `const Set<String> _titleAcronyms = { 'sre','fde','tpm','em','swe','sde','sdet','qa','dba','ux','ui','devops','mlops','vp','svp','evp','avp','ceo','cto','cfo','coo','cio','cmo','ciso','cpo','cro','gm','md','pmm','bdm','csm','tam','hrbp','pm','ai','ml','se','ae' };` (store lowercase; `R&D` handled by also matching a token equal to `r&d`). GATING DECISION (documented): acronyms are NOT hard name-penalizers. Instead they contribute to the "this line is a title" signal: in the Latin pure-title `words.every(...)` check (line ~748), treat a word as a title word if `keywords.title.contains(w) || _titleModifierWords.contains(w) || _titleAcronyms.contains(w)`. Additionally, when a line contains an acronym token AND (another title/modifier word is present on the line OR a title anchor is adjacent), add it to the `-30` title signal. CRITICAL ACRONYM FALSE-POSITIVE GUARD: a STANDALONE single acronym token that is the SOLE content of a short, plausible-name line (1–2 tokens, no other title word, no adjacent title anchor) must NOT trigger the pure-title penalty — this protects a person named "Ai Nakamura", initials "A.I. Smith", "Se-jin Park", or a 2-letter name. Implement by requiring, for the acronym to count toward pure-title, that EITHER the line has ≥2 words with ≥1 being a non-acronym title/modifier word, OR a title anchor is within `maxHeight*3.0`. A line that is ONLY an acronym with no corroboration is left to the normal name scoring.
      Files: `.../lib/src/secbizcard_ocr_impl.dart`
      Verify: `fvm spawn 3.38.9 test test/parsing_test.dart` — all 47 existing tests pass. In particular confirm the `AWS` test (company detection relies on `solutions`/`services` company keywords) and the `Kantar`/`Palo Alto` title tests still pass.

- [ ] 5. Add new regression tests for the Microsoft case, the new lexicon/acronyms, email patterns, role-mailbox, and the acronym guard.
      Add tests to the existing `group('parseLines field assignment ...')` in `test/parsing_test.dart`, following the existing `OcrLine(text:..., box: Rect.fromLTWH(...))` + `SecBizCardOcr().parseLines(lines)` pattern. Cases (each asserts `r.displayName`):
      - **Microsoft (primary)**: name `Joanne Tsai`, title `Solution Engineer`, email `joannetsait@microsoft.com`, company `Microsoft Taiwan Corp.`, a phone line. Assert `r.displayName == 'Joanne Tsai'` and `isNot(contains('Solution'))` and `r.title` contains `Solution Engineer`.
      - **flast email pattern**: same card but email `jtsai@microsoft.com` → still `Joanne Tsai` (exercises `flast` branch of the matcher).
      - **firstl email pattern**: email `joannet@microsoft.com` → still `Joanne Tsai` (exercises `firstl`/prefix branch).
      - **RealName + SRE**: name `David Chen`, title `SRE`, email `davidchen@...` → name `David Chen`, title not the name; assert SRE is treated as title (`r.title` contains `SRE`).
      - **RealName + FDE**: name `Emily Wang`, title `FDE` (Forward Deployed Engineer), email `emilyw@...` → name `Emily Wang`.
      - **RealName + Cloud Architect**: name `Michael Lee`, title `Cloud Architect` → name `Michael Lee`, not `Cloud Architect`.
      - **RealName + Customer Success Manager**: name `Sarah Kim`, title `Customer Success Manager` → name `Sarah Kim`.
      - **Role mailbox guard**: a card whose only email is `info@acme.com` (or `sales@`), real name `Peter Lin`, title `Account Manager`. Assert the email signal does NOT distort selection — `r.displayName == 'Peter Lin'` (verifies the role-mailbox guard means neither boost nor demotion fired incorrectly).
      - **Acronym false-positive guard**: a card with name line `Ai Nakamura` (standalone, no adjacent title) + a separate real title line `Product Manager` + email `ainakamura@...`. Assert `r.displayName == 'Ai Nakamura'` — the acronym `ai` as the sole/corroboration-free name line is NOT penalized as a title.
      Files: `.../packages/SecBizCard_OCR/test/parsing_test.dart`
      Verify: `/Users/jack/fvm/bin/fvm spawn 3.38.9 test test/parsing_test.dart` from the package dir — the 47 existing PLUS all new tests pass (expect `All tests passed!`). If a new case fails, adjust the weights (`emailNameBoost`, `emailNameMismatchPenalty`) or lexicon membership — not the test expectations — until the real name wins each case without regressing the 47.

- [ ] 6. Update CHANGELOG and note the release dependency.
      Add a dated entry to `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name/packages/SecBizCard_OCR/CHANGELOG.md` summarizing: coverage-based bidirectional email↔name matcher, email-mismatch demotion, role-mailbox guard, expanded title lexicon + gated acronym set with the standalone-acronym guard, and the new regression tests. Explicitly note in the plan deliverable and the CHANGELOG that **this fix reaches end users only when the app is rebuilt and released against the updated `SecBizCard_OCR` package** — it is a client-side parsing change with no backend/Remote-Config component, so no deploy is involved, only an app release.
      Files: `.../packages/SecBizCard_OCR/CHANGELOG.md`
      Verify: `fvm spawn 3.38.9 test test/parsing_test.dart` — full suite green (final confirmation nothing regressed).

## Notes / open assumptions
- Weights (`emailNameBoost=80`, `emailNameMismatchPenalty=-50`) are chosen to beat the `+45` Latin structure bonus; if a specific real card needs tuning, adjust the default constant — do not restructure. They are threaded through `_tune(...)` so a future remote-tuning map can override them without code change, but no `parseLines(tuning:)` API change is made in this task.
- CJK-romanization "loose" matching is implemented pragmatically via the alpha-only `euAlpha` prefix matching (handles pinyin/Wade-Giles reconstructed from Latin tokens on the card). A full romanization transliteration table is out of scope; the prefix/startsWith matching covers the common `swenlai@`/`shaohung.yen@` style already present in the suite.
- The user's "problem 1" (pre-crop not catching the card edge) is a SEPARATE geometric-detection concern and is explicitly NOT addressed by this plan.
