# Business Card Management App – Technical Specification

## 1. Objective

Develop a Flutter-based mobile application that enables users to:
- Import business contacts from external sources via `.vcf` (vCard)
- Capture business card images using the phone camera
- Automatically detect, crop, and perspective-correct business card images
- Perform on-device OCR to extract key contact information
- Structure extracted data into editable contact records
- Export contacts back to `.vcf` format for interoperability

The system must operate **offline-first**, with no dependency on proprietary third-party APIs (e.g. CamCard).

---

## 2. Supported Platforms

- iOS (minimum iOS 14)
- Android (minimum Android 9 / API 28)

---

## 3. High-Level Architecture

Flutter UI  
Application Layer (Import / Camera / OCR / Structuring / Export)  
Domain Models (ContactModel)  
Data Layer (Local DB + File Storage)  
Native Layer (OpenCV via Platform Channels)

---

## 4. Contact Data Model

```json
{
  "id": "uuid",
  "name": "string",
  "company": "string",
  "title": "string",
  "department": "string",
  "email": "string",
  "phone": "string",
  "address": "string",
  "images": {
    "original": "path/to/original.jpg",
    "flat": "path/to/processed.jpg"
  },
  "source": "vcf | ocr",
  "createdAt": "ISO-8601"
}
```

---

## 5. vCard Import Specification

Supported versions: 2.1 / 3.0 / 4.0 (best-effort)

Supported field mapping:
FN/N → name  
ORG → company  
TITLE → title  
EMAIL → email  
TEL → phone  
ADR → address

---

## 6. Image Processing

- Camera capture (original image preserved)
- OpenCV native pipeline:
  grayscale → blur → edge → contour → quadrilateral → perspective transform
- Output: original + flattened card image

---

## 7. OCR

- Google ML Kit (on-device)
- Input: flattened card image
- Output: text blocks with bounding boxes

---

## 8. Field Structuring

- Regex for email & phone
- Heuristics for name/company/title/address
- Positional + keyword weighted scoring

---

## 9. User Review

- All fields editable
- User confirmation required before save

---

## 10. Export

- vCard 3.0
- System share sheet

---

## 11. Non-Functional

- Offline-first
- Privacy-first
- Local storage only

---

## 12. Out of Scope

- Cloud sync
- CRM integration
- AI/LLM parsing
