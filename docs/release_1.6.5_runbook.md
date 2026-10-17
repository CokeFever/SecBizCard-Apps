# 1.6.5 Release Runbook (build 197)

Prepared 2026-10-16. This release bundles the OCR-stability + i18n/field-coverage + feedback
batch across BOTH repos. Agent has done all code + merges + pushes. **Releasing (tags + the
Firebase `full` deploy) is the owner's call and is listed below.**

## What shipped in this batch (6 units)

| Unit | What | Repo / commit |
|------|------|---------------|
| U1 | OCR parser: recover department under degenerate all-y=0 geometry (source-order fallback) | SecBizCard `b223f8b` |
| U2 | Backend `bboxFromVertices`: remove `Math.min(...,0)` flooring so line tops aren't 0 | SecBizCard `8094baa` |
| U3 | App i18n/field coverage: fax/taxId localized, department→Review/Edit-Profile, website→Detail/Edit, mobile unified, address→Edit-Contact, custom-field "Add Field" system localized (35 ARB keys ×6) | SecBizCard-Apps `c00144b` |
| U4 | Manage Contexts: `showDepartment` toggle (business=on, social/lite=off) | SecBizCard-Apps `1b57e1a` |
| U5 | OCR feedback: detached background upload (submit → return to capture immediately → background upload → root toast); backing out no longer cancels it | SecBizCard-Apps `6d87ab4` |
| U6 | Web editor: fax/taxId reserved round-trip + localized rows; guide "Report a poor scan" section reworded (5 locales) | SecBizCard `81ed832` |

## State right now (DONE by agent)

- **SecBizCard-Apps main = `81d6f6e`** (1.6.5+197; U3/U4/U5 + OCR ref pinned to `b223f8b` + git-ref pubspec.lock). Pushed.
- **SecBizCard main = `81ed832`** (U1/U2/U6). Pushed.
- App's pinned OCR ref `b223f8b` is confirmed present on SecBizCard main → Cloud Build resolves it.
- `pubspec.lock` is in **git-ref mode** pinning `b223f8b` (not path mode) → CI/Cloud Build resolves OCR cleanly.
- All worktrees removed; both repos clean on main.

## IMPORTANT: "does not affect the live/published version"

- **Tagging the app (step 1) ships to TestFlight + Play *internal testing* only — it does NOT touch the live store listing.** Safe to tag and device-test.
- **The backend `full` deploy (step 3) DOES change production** — U2's bbox change affects `recognizeCard` for ALL app versions (incl. older store builds). Blast radius is app-parser-only (confirmed): older parsers simply get correct coordinates (department may start extracting); no crash. Still, it is a production backend change — do it deliberately, AFTER app device-testing is satisfied.
- **Coupling to know:** department extraction is fully correct only once U2 (backend) is deployed. U1 (app parser) is a best-effort fallback for degenerate geometry. On TestFlight *before* the backend deploy, verify the things that DON'T need the backend (name/company/title no-regression, feedback flow, 5-language labels); verify department extraction *after* the `full` deploy.

## RELEASE STEPS (owner)

### Step 1 — Tag the app (both platforms, build 197) → test tracks
```
git -C /Users/jack/_Projects/SecBizCard-Apps tag -a android/v1.6.5+197 -m "1.6.5+197: OCR stability (department geometry), i18n/field coverage, detached feedback upload"
git -C /Users/jack/_Projects/SecBizCard-Apps tag -a ios/v1.6.5+197     -m "1.6.5+197: OCR stability (department geometry), i18n/field coverage, detached feedback upload"
git -C /Users/jack/_Projects/SecBizCard-Apps push origin android/v1.6.5+197 ios/v1.6.5+197
```
- `android/v1.6.5+197` → GCP Cloud Build (`android-release-build`, us-central1) → AAB → Play internal testing.
- `ios/v1.6.5+197` → Xcode Cloud → TestFlight.
- This brings iOS (was 193) and Android (was 196) back in sync at 197.

### Step 2 — Device-test on TestFlight / Play internal (the "OCR must be stable before release" gate)
- **OCR no-regression (critical — bbox geometry changed):** scan several real cards, confirm name / company / title still correct.
- **Feedback flow:** submit OCR feedback → screen returns to capture immediately → navigate away → upload still completes in background → success toast → confirm the feedback doc lands (backend admin CLI `scripts/ocr_feedback.mjs list`).
- **i18n:** switch app language across en/zh-Hant/zh-Hans/ja/ko → fax/taxId/department/website labels are localized (no English fallback) on Detail/Edit/My-Profile/Review; Manage Contexts shows the department toggle.
- **Department extraction:** best-effort on TestFlight pre-backend-deploy; fully verify after step 3.

### Step 3 — Deploy backend + web (ONLY after step 2 is satisfied; this touches production)
```
# one-time if not already set:
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
# full deploy ships U2 (functions) + U6 (website) together (no functions-only target exists):
gh workflow run firebase_deploy.yml --ref main -f deploy_target=full
```
- `full` also redeploys functions / rules / storage / hosting. Confirm `REVENUECAT_WEBHOOK_AUTH` is set first.
- Watch the run: `gh run list --workflow=firebase_deploy.yml -L 3` then `gh run view <id> --json conclusion` (read it explicitly; don't infer from tail).

### Step 4 — Post-deploy web verification (strict CSP)
```
curl -s https://ixo.app/editor -D - -o /dev/null | grep -i content-security-policy   # script-src has NO 'unsafe-inline'
```
- Confirm HTTP 200, `script-src` has no `unsafe-inline`, inline importmap/script count 0.
- Eyeball hydration: open ixo.app/editor and ixo.app/guide in a browser — editor stepper renders, guide shows sections, no white screen. (CSP headless-Chrome hydration already passed pre-merge; this is the live confirmation.)
- Then re-verify department extraction on a device now that backend geometry is correct.

### Step 5 — Promote to production (when happy)
- Play Console: promote the internal-testing build to production as desired.
- App Store Connect: submit the TestFlight build for review.
- (Both are manual store actions — the tags above only populate the test tracks.)

## Rollback notes
- App: a bad 197 stays in test tracks; don't promote. Live users unaffected until you promote.
- Backend `full` deploy: if the bbox change causes any OCR regression in production, redeploy the
  previous functions (revert `8094baa` on main, `full` deploy again). Blast radius is OCR parsing only.
