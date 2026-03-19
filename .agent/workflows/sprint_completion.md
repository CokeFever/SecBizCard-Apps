---
description: detailed instructions on how to close out a sprint, ensure code quality, and update the roadmap
---

# Sprint Completion Protocol

Follow these steps at the end of every Sprint to ensure the project remains healthy and deployable.

## 1. Clean and Rebuild
Force a clean state to remove stale artifacts and ensure `build_runner` works correctly.

```powershell
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

// turbo-all

## 2. Static Analysis
Run the analyzer to catch syntax errors, type mismatches, and lint warnings.

```powershell
flutter analyze
```

**Action**: If errors are found (`Exit code: 1`), you **MUST** fix them before proceeding.
*   Check `analysis.log` or console output.
*   Common issues: `Undefined class` (check imports), `Target of URI doesn't exist` (check `build_runner`), `Relative imports` (use `package:` imports).

## 3. Manual Verification
Perform a quick sanity check of the features implemented in this sprint.
*   **Run**: `flutter run -d windows` (or chrome)
*   **Verify**: Check critical flows (e.g., Login, Profile Display).

## 4. Documentation Update (Roadmap)
Mark completed tasks in `ixo_feasibility_and_roadmap.md`.

## 5. Walkthrough Creation
Generate a `walkthrough.md` artifact summarizing:
*   Changes made.
*   Files modified.
*   Verification results (screenshots if possible).

## 6. Notification
Notify the user that the Sprint is complete and the codebase is clean.
