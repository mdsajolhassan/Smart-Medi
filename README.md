# Smart Medi

Smart Medi is a healthcare, emergency SOS, and medical inventory application developed for the Bangladesh Army University of Science and Technology (BAUST) community.

## Key Features

- **Authentication & RBAC**: Strict role-based access control with student onboarding, email verification, domain policy, and Google Sign-In.
- **AI-Powered Medical Onboarding**: Multimodal clinical document analysis using Google Gemini AI with deterministic extraction, allergen detection, chronic condition normalization, medication timeline parsing, and zero-hallucination guardrails.
- **Emergency SOS (Phased)**: Rapid alert system for campus medical emergencies with geolocation and medical profile broadcasting.
- **Zero-Trust Firestore & Storage Rules**: Protected role escalations, doctor-exclusive clinical history inspection, admin medical privacy guarantees, and transactional student ID collision prevention.

## Documentation

- [Phase 1 Security & Deployment Guide](README_PHASE1_SECURITY.md)

## Development & Testing

```bash
# Analyze codebase
flutter analyze

# Run all automated tests
flutter test
```
