# OCR name-vs-title fix: coverage-based email cross-reference + title lexicon expansion

The change stops a job title from winning the Name slot on business cards. It replaces the old weak `+30` whole-word email boost with a coverage-based, bidirectional email↔name matcher (`_emailNameCoverage`), adds a mismatch demotion for name-shaped Latin lines that reconstruct no known personal local-part, gates both signals behind a role-mailbox guard, and expands the title lexicon with modern head/modifier words plus a corroboration-gated acronym set. All changes are confined to the client-side `SecBizCard_OCR` package (`secbizcard_ocr_impl.dart`), with nine new regression tests in `parsing_test.dart` and a CHANGELOG entry. The verification note records `All tests passed!` at 56 tests (47 original + 9 new) on fvm 3.38.9 and a clean `analyze` (one pre-existing package-name lint only).

Watch for: the 0.5 single-name coverage tier yields only `+40`, below the `+45` Latin structure bonus — harmless for the tested cases (competing titles are pure-title penalized at `-120`) but a latent weakness (confirmed). The demotion's `startsKnownSurname` guard reuses the CJK-only `_commonChineseSurnames` set, so it never fires for Latin lines; the real protection for genuine Latin names is their own `coverage > 0`, which holds, so this is a cosmetic mismatch vs the plan wording, not a defect (confirmed).

**Verdict**: APPROVED

## High-level view

The primary fix is the coverage matcher. It reconstructs `first.last`, `firstlast`, `last.first`, `flast`, `firstl`, `allJoined`, and single `first`/`last` from the candidate's tokens and matches them against the local-part both exactly and by prefix (either direction), tolerating a trailing OCR character and numeric suffixes via an alpha-only reduction. The strongest tier found drives the boost: 1.0→+80, 0.9→+72, 0.75→+60, 0.5→+40. The +80/+60 tiers beat the +45 Latin structure bonus, which is what the Microsoft cases need.

The demotion is the mirror signal: a Latin line that got the +45 structure bonus, sits within three line-heights of a title anchor, and reconstructs none of a personal local-part is docked `-50`. Because a real name always has coverage > 0, it reaches the boost branch and never the demotion branch, so the demotion only lands on title lines like "Solution Engineer".

Both signals are gated behind `emailIsPersonal`, which excludes an 18-entry role-mailbox set after normalizing separators so `no-reply` collapses to `noreply`. A shared mailbox neither boosts nor demotes.

The lexicon expansion adds head nouns to `k.title` and pre-head modifiers to `_titleModifierWords` so multi-word modern titles satisfy the pure-title `every(...)` check and take the `-120` penalty. "solutions" is added to the modifier set without being removed from `k.company`, preserving company detection. The acronym set contributes to the title signal only with corroboration (a second title word on a ≥2-word line, or an adjacent title anchor), which keeps a standalone-acronym name like "Ai Nakamura" out of the title bucket.

<details>
<summary>Issues (2)</summary>

1. **0.5 coverage tier underweights single-name matches** — a name resolved only by a single first/last match scores +40, below the +45 Latin structure bonus; harmless now (tested competing titles are pure-title penalized) but could let a title win if it ever carries only the structure bonus. Consider raising the single-name tier or its multiplier in a future tune. Non-blocking.
2. **Demotion surname guard uses CJK-only set for a Latin path** — `startsKnownSurname` checks `_commonChineseSurnames` against a Latin token, so it never fires; the plan's intended "known surname" guard is effectively a no-op. Real Latin names are still protected by `coverage > 0`, so behavior is correct, but the guard is dead code / misleading vs the plan. Non-blocking; optionally drop or replace with a Latin surname check.

</details>

<details>
<summary>Details</summary>

## Coverage matcher correctness against the required email patterns

The matcher is the heart of PART 1 and it holds up against the called-out patterns. `eu` keeps `[a-z0-9]`, `euAlpha` strips to `[a-z]`, so numeric suffixes (`earth80`, `joannetsai2`) fall out of the alpha form while prefix matching still works against both. The `prefix` helper matches in both directions (`eu.startsWith(a)`, `euAlpha.startsWith(a)`, and candidate-startsWith-euAlpha for length ≥ 4), which is what gives the "trailing stray OCR char" tolerance the Microsoft `joannetsait@` case needs.

Tracing the three required Microsoft cases for "Joanne Tsai" (first=`joanne`, last=`tsai`):
- `joannetsait@` → euAlpha=`joannetsait`. `firstlast`=`joannetsai`; `prefix('joannetsai')` → `euAlpha.startsWith('joannetsai')` true → 0.9 → +72. Beats +45. ✓
- `jtsai@` → euAlpha=`jtsai`. `flast`=`jtsai`; `eq('jtsai')` → 0.75 → +60. ✓
- `joannet@` → euAlpha=`joannet`. `firstl`=first+`t`=`joannet`; `eq('joannet')` → 0.75 → +60. ✓

The boost at these tiers clears the +45 structure bonus that "Solution Engineer" would otherwise ride on, and "Solution Engineer" additionally takes `-120` (see lexicon below), so the name wins decisively.

The min-token-length guard is kept: single-name tiers require `first.length >= 3` / `last.length >= 3`, and `euAlpha.length < 2` returns 0.0 early. The signal never invents a name — it only adjusts the score of a candidate that is already an OCR line (the matcher is called per-candidate inside `_scoreName`), satisfying the "never invents a name absent from the OCR lines" requirement.

## Email-mismatch demotion is correctly one-sided

The demotion fires only when `gotLatinStructureBonus && nearTitleAnchor && coverage == 0`. A genuine name has coverage > 0 and takes the boost branch instead, so it is structurally impossible to demote the real name through this path — the `else if` guarantees mutual exclusion with the boost. "Solution Engineer" with `joannetsait@` reconstructs nothing (solution/engineer vs joannetsai), sits by the Microsoft/phone block, and is docked `-50` on top of its pure-title `-120`.

The `startsKnownSurname` sub-guard is where the implementation diverges from the plan: the plan said "does NOT start with/contain a known surname," implying a general surname check, but the code reuses `_commonChineseSurnames` (Han characters). `candidateTokens.first` for a Latin line is a Latin word, so the check is always false and the demotion always proceeds for qualifying Latin lines. This does not cause a wrong outcome — the only Latin lines reaching here are coverage-0 title-adjacent name-shaped lines, which are exactly what should be demoted — but the guard is effectively dead for the Latin path it guards. Flagged as non-blocking.

## Role-mailbox guard

`emailIsPersonal` normalizes `-` and `.` out of the local-part before checking the 18-entry `_roleMailboxLocalParts` set, so `no-reply`/`no.reply` → `noreply` is caught. When the mailbox is a role address, both the boost and the demotion are skipped, so `info@acme.com` leaves "Peter Lin" to win on its own structural/positional merits and does not demote "Account Manager" either. The `info@` test asserts exactly this. The allowlist guard required by PART 1 is present and sound.

## Title lexicon and acronym gating (PART 2)

"solution" is added to both `k.title` (head noun) and `_titleModifierWords` (modifier), and "engineer" already lives in `k.title`, so "Solution Engineer" now satisfies `words.every(isTitleWord)` → `-120`. The other called-out modern titles are covered the same way: Cloud Architect, Customer Success Manager, Platform/Field/Sales Engineer, Site Reliability Engineer, Data Scientist all resolve pure-title via the expanded modifier set plus existing heads.

The acronym set is gated exactly as the plan requires. An acronym counts toward pure-title only when `acronymCorroborated` = (`words.length >= 2 && hasNonAcronymTitleWord`) OR `nearTitleAnchor`. A standalone single-acronym line with no adjacent title anchor is left to normal name scoring, protecting "Ai Nakamura" (where `ai` is in the set). The separate acronym-only title tagging at line 306 is also 1-token-guarded (`toks.length == 1 && _titleAcronyms.contains(toks.first)`), so a bare "SRE" line is bucketed as a title candidate while a 2-word name is not. The soft `-30` acronymTitleSignal fires only for a corroborated lone acronym adjacent to a title anchor, nudging "SRE" below the name without hard-penalizing it. The false-positive guard is sound for the short-name / initials cases called out.

Company detection is not broken: "solutions" remains in `k.company`, so the `-80` company penalty is independent of its new modifier-set membership. The verification note states the AWS/Kantar/Palo Alto company and title tests stay green, consistent with leaving `k.company` untouched.

## Test coverage

All nine required new tests are present and assert the right outcomes: the Microsoft primary case asserts `displayName == 'Joanne Tsai'`, `isNot(contains('Solution'))`, and `title` contains `Solution Engineer`; the flast/firstl variants exercise the 0.75 tiers; SRE/FDE/Cloud Architect/Customer Success Manager cover the lexicon and acronym title paths; the `info@` test covers the role-mailbox guard; and the "Ai Nakamura" test covers the standalone-acronym guard. The verification note documents one existing test ("Sally Chen 陳曉君", `sachen@paloaltonetworks.com`) that was rebalanced by extending the single-name tier to use `euAlpha.contains(...)` rather than prefix-only — I confirmed that test still asserts `contains('Sally Chen')` and the same email, so no assertion was weakened. `sachen` contains `chen`, so the surname credits 0.5 as described.

Not re-run here per instructions: the test suite and `flutter analyze`. The verification note gives the exact fvm 3.38.9 commands and before/after counts (47 → 56, all passing; analyze clean except the pre-existing `package_names` lint). Evidence is present and specific, so the gate relies on it rather than re-running.

Not tested: a card where the real name is resolvable ONLY by the 0.5 single-name tier while a competing non-pure-title line carries the +45 structure bonus — the latent weakness in Watch For. No such case exists in the suite, so it is untested; it is also not a scenario the user reported.

</details>

<details>
<summary>File map</summary>

- `packages/SecBizCard_OCR/lib/src/secbizcard_ocr_impl.dart` — new `_emailNameCoverage` helper, coverage-based boost + mismatch demotion in `_scoreName`, `emailIsPersonal` role-mailbox gate, acronym-corroboration logic in the pure-title check, acronym-only title tagging in `parseLines`, and lexicon additions (`k.title` heads, `_titleModifierWords`, new `_titleAcronyms` and `_roleMailboxLocalParts` sets).
- `packages/SecBizCard_OCR/test/parsing_test.dart` — 9 new regression tests (Microsoft primary + flast/firstl, SRE, FDE, Cloud Architect, Customer Success Manager, role-mailbox, acronym guard).
- `packages/SecBizCard_OCR/CHANGELOG.md` — dated entry; notes the fix ships only with an app rebuild/release (no backend/deploy).

Full diff: `git diff main` on branch `fix/ocr-name-vs-title` in `/Users/jack/_Projects/SecBizCard/.worktrees/ocr-name`.

</details>
