# Architectural & Technical Decisions

This document records the key architectural and technical decisions made for the Business Card Management App.
Its purpose is to preserve context, reduce repeated debates, and clarify trade-offs for future contributors.

---

## 1. No Official CamCard API Integration

### Decision
The system does **not** integrate with CamCard APIs or cloud services.
Data import is supported exclusively via `.vcf` (vCard) files.

### Rationale
- CamCard does not provide a stable, public API for third-party integration
- Any reverse-engineering or unofficial access would be fragile and legally risky
- vCard is an industry-standard, portable, and user-controlled format

### Trade-offs
- Users must manually export from CamCard
- No real-time sync with CamCard

### Revisit If
- CamCard releases an official, documented API
- Legal and commercial agreements are established

---

## 2. vCard Parsing Strategy (Scheme A)

### Decision
The application parses `.vcf` files directly instead of importing via system contacts.

### Rationale
- Avoids requesting system contacts permission
- Prevents polluting the user’s personal address book
- Ensures deterministic, testable import behavior
- Keeps data sandboxed within the app

### Trade-offs
- Must handle multiple vCard versions manually
- Slightly more parsing logic required

### Revisit If
- Users explicitly request deep system contacts integration
- OS-level contact sync becomes a core feature

---

## 3. Offline-First Architecture

### Decision
All core functionality (OCR, parsing, storage) operates fully offline.

### Rationale
- Business cards may contain sensitive personal information
- Avoids dependency on network availability
- Eliminates recurring cloud OCR costs
- Improves perceived performance and reliability

### Trade-offs
- Slightly larger app size
- OCR quality limited to on-device models

### Revisit If
- Enterprise tier requires centralized data sync
- Optional cloud-based enhancement is added (opt-in)

---

## 4. OCR Engine Selection: Google ML Kit

### Decision
Use Google ML Kit on-device OCR for all text recognition.

### Rationale
- High accuracy for small fonts and mixed CN/EN text
- Mature mobile SDK with Flutter support
- Runs fully on-device
- No model training required

### Rejected Alternatives
- **Tesseract**: Poor accuracy on business cards
- **Cloud OCR APIs**: Cost, latency, privacy concerns
- **Custom ML models**: High maintenance, low ROI

### Trade-offs
- Limited customization of OCR model
- Depends on Google-provided binaries

### Revisit If
- ML Kit is deprecated or significantly restricted
- Custom domain-specific OCR becomes a competitive advantage

---

## 5. Image Processing via OpenCV (Native)

### Decision
Automatic card detection, cropping, and perspective correction are implemented using OpenCV in native code (Android/iOS).

### Rationale
- Reliable contour detection and perspective transforms
- Proven approach used by document scanning apps
- Superior accuracy compared to pure Flutter/Dart image libraries

### Rejected Alternatives
- Pure Dart image processing: insufficient for robust edge detection
- Manual crop UI only: poor UX, non-competitive

### Trade-offs
- Additional native code maintenance
- Slightly higher build complexity

### Revisit If
- Flutter ecosystem gains mature, performant CV libraries
- Platform channels become a maintenance bottleneck

---

## 6. Heuristic-Based Field Structuring (Rule + Scoring)

### Decision
Extract structured contact fields using deterministic rules and weighted heuristics, not LLMs.

### Rationale
- Business cards follow relatively stable visual and semantic patterns
- Rules are explainable, debuggable, and tunable
- No inference latency or token cost
- Works fully offline

### Rejected Alternatives
- LLM-based parsing: cost, privacy, unpredictability
- Fully ML-based classifiers: training data requirements

### Trade-offs
- Edge cases may require manual correction
- Rules must be tuned over time

### Revisit If
- Large labeled dataset becomes available
- Hybrid LLM-assisted parsing is added as an optional feature

---

## 7. User-in-the-Loop Confirmation

### Decision
All OCR-extracted data must be reviewed and confirmed by the user before saving.

### Rationale
- Prevents silent data corruption
- Increases user trust
- Reduces support burden from incorrect auto-imports

### Trade-offs
- One additional interaction step
- Slightly slower capture flow

### Revisit If
- Confidence scoring becomes highly reliable
- Bulk auto-import mode is introduced

---

## 8. Local-Only Storage by Default

### Decision
All contact data and images are stored locally on the device.

### Rationale
- Simplifies compliance and privacy considerations
- Avoids authentication and backend complexity
- Aligns with offline-first philosophy

### Trade-offs
- No cross-device sync
- Risk of data loss without backup

### Revisit If
- Paid tier requires cloud sync
- Enterprise customers request centralized storage

---

## 9. vCard 3.0 as Export Standard

### Decision
All exported contacts use vCard 3.0 format.

### Rationale
- Widely supported by iOS, Android, and desktop systems
- Simpler and more consistent than 4.0
- Sufficient for all supported fields

### Trade-offs
- No support for advanced 4.0 features
- Limited metadata expressiveness

### Revisit If
- Strong demand for richer vCard features
- Compatibility issues arise

---

## 10. No AI/LLM Dependency in v1

### Decision
The initial release does not depend on any AI/LLM services.

### Rationale
- Reduces cost and operational risk
- Improves predictability and testability
- Avoids privacy and compliance concerns

### Trade-offs
- Less “intelligent” handling of ambiguous layouts
- Heuristic tuning required

### Revisit If
- Product differentiation requires semantic reasoning
- Optional AI-enhanced mode is introduced

---

## 11. Engineering Philosophy

- Prefer **deterministic systems** over probabilistic ones in v1
- Optimize for **user trust and data ownership**
- Build foundations that allow AI augmentation later, not the reverse

---
