# Building a SecBizCard Import `.zip`: Packaging Structure & Data-Integration Strategy

This is the **producer-side companion** to
[`zip_import_format.md`](./zip_import_format.md). The format doc defines *what a
valid package looks like*; this doc explains *how to build one* from messy
real-world source data, and the integration decisions that make the result
import cleanly.

Audience: anyone (or any AI/LLM) assembling a `.zip` from scraped, exported, or
freshly-OCR'd cards.

---

## 1. Package structure at a glance

```
import.zip
├── manifest.json         # required, UTF-8, at the zip root
└── images/               # optional; all card images live here
    ├── 0001_front.jpg
    ├── 0001_back.jpg
    ├── 0002_front.jpg
    └── ...
```

- `manifest.json` holds `version`, optional `source`, and a `contacts` array.
- Each contact carries structured text fields plus optional image references
  (`frontImage` / `backImage` / `originalImage`) that are **relative paths into
  the zip**.
- Field meanings and the full schema are in
  [`zip_import_format.md`](./zip_import_format.md); this doc won't repeat them.

---

## 2. The core integration problem

Source data almost never arrives in the shape the manifest wants. You typically
have:

- A **text table** (Excel/CSV/vCard) where one logical field is split across
  several columns, or names/titles are misfiled.
- A **pile of images** named by some opaque id, not by contact.

Integration = turning those into one clean `contacts[]` array where each entry's
fields are coalesced and each entry points at the right image.

### 2.1 Coalescing multi-column fields

Card exports commonly split a field into ranked columns, e.g.
`Company1 / Company2 / Company(Others)`, or three phone columns, or two full
address blocks. Strategy: **take the first non-empty** of each ranked group.

```
company  = first_non_empty(Company1, Company2, Company(Others))
phone    = first_non_empty(Telephone1, Telephone2, Telephone(Others))
mobile   = first_non_empty(Mobile1, Mobile2, Mobile(Others))
email    = first_non_empty(Email1, Email2, Email(Others))
```

Keep extras (2nd/3rd values) only if you have a place for them (e.g. an
`emails[]` array or a note); otherwise dropping them is acceptable for a first
import.

### 2.2 Assembling a single-line address

Card apps store addresses as separate `country/state/city/street/zip` columns.
The manifest's `address` is a single human-readable line, so join the non-empty
parts in reading order:

```
street  = join(street1, street2)
address = join_nonempty([street, city, state, zip, country], ", ")
```

### 2.3 Handling misfiled data

OCR-based exporters sometimes put the person's **name into the department
column** (or leave name blank). Add a targeted repair: *if `name` is empty but a
department value exists, promote the department to the name and clear it.* This
keeps every contact identifiable instead of importing a nameless row. Treat OCR
glitches in field values (mojibake, wrong field) as **source-data quality**, not
something the packager should silently rewrite beyond obvious, safe repairs.

### 2.4 Joining images to contacts

Two reliable strategies:

1. **By id** — the strongest. If you scraped each image keyed by a stable card
   id and your text rows also carry that id, join on it. Robust to reordering and
   lets you re-run either half independently.
2. **By row order** — acceptable when the text export and the image set were both
   produced in the same sort order. Simpler, but fragile if either side is
   re-sorted.

Whichever you use, produce a `mapping.csv` (`id ↔ name ↔ image_filename`) as an
intermediate artifact and **verify the join** before packaging.

---

## 3. Filename & encoding discipline

- **Rename images to clean ASCII** inside the zip (`0001_front.jpg`), even if the
  originals had names with spaces or CJK characters. The manifest's
  `frontImage` points at these clean names. This avoids cross-platform zip
  filename issues.
- Write `manifest.json` as **UTF-8** (field *values* can be any language; only
  the image *filenames* need to be ASCII-safe).
- Keep images reasonably sized (≤ ~3 MB each). A batch of a few hundred cards
  produces a zip of a few tens of MB, which is fine to import on-device but is
  held in memory during parsing — avoid extreme resolutions.

---

## 4. Reference build recipe

A repeatable way to turn `text + images + mapping` into `import.zip`:

1. **Parse the text source** into rows of raw columns.
2. For each row, **coalesce** fields (§2.1–2.3) into the manifest's field names.
3. **Skip empty rows** — if a row has no name, email, phone, or mobile, drop it
   (the app skips these anyway; dropping them keeps the manifest honest).
4. **Look up the image** for the row via the mapping; if present, copy it into
   the package as `images/NNNN_front.jpg` and set `frontImage` accordingly.
5. **Emit `manifest.json`** with `version: 1`, a `source` tag, and the
   `contacts[]` array.
6. **Zip** `manifest.json` + `images/`.

### Pre-flight validation (do this before handing the zip to anyone)

- `manifest.json` parses as JSON and has a `contacts` array.
- Every `frontImage`/`backImage` path referenced actually exists in the zip.
- Every image is a real image (magic bytes / `file`), not an HTML error page.
- Counts line up: contacts vs. images vs. source rows.
- Spot-check a few rich contacts (address + fax + multiple phones) end-to-end.

---

## 5. What the app does on import (so you can predict results)

Understanding the consumer side helps you package correctly:

- The app parses the zip **on-device**, extracts referenced images to a temp
  dir, and builds one contact per manifest entry with a fresh internal id and
  `source: "ocr"`.
- Image fields map straight through: `frontImage → cardFrontPath`,
  `backImage → cardBackPath`, `originalImage → originalImagePath`. The app then
  copies those into its permanent storage automatically — you don't manage app
  paths.
- A **missing image reference is non-fatal**: the contact still imports, just
  without that image. So a partial image set still yields a full text import.
- Import is **additive** (each entry becomes a new contact); it does not
  overwrite or dedupe existing contacts. Re-importing the same package creates
  duplicates — package once, or dedupe on your side first.
- Nothing is uploaded to a backend.

### Determinism & re-runs

Because the app assigns ids at import time, the manifest should **not** carry or
assume ids. If you need idempotent re-imports, dedupe on your side (e.g. keep a
record of what you've already imported) rather than relying on the app.

---

## 6. Minimal valid example

```json
{
  "version": 1,
  "source": "example",
  "contacts": [
    {
      "name": "Jane Doe",
      "company": "Example Inc.",
      "title": "Engineer",
      "email": "jane@example.com",
      "mobile": "+10000000000",
      "frontImage": "images/0001_front.jpg"
    }
  ]
}
```

```
import.zip
├── manifest.json
└── images/
    └── 0001_front.jpg
```
