# Smart Medi — BAUST Medical Center

Campus healthcare app for **Bangladesh Army University of Science and Technology (BAUST)**. It brings emergency
SOS, digital prescriptions, AI-read medical history, the pharmacy and the blood bank into one Flutter + Firebase app.

**Live app:** https://smart-medi-galib.web.app

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-blueviolet?logo=dart&logoColor=white)](https://riverpod.dev)
[![Tests](https://img.shields.io/badge/Tests-143%20passing-brightgreen)](#testing)

---

## Roles

| Role | What they can do |
|---|---|
| **Student** | Raise an emergency SOS, upload old prescriptions (AI extracts the history), view and **download prescriptions as PDF**, join the blood bank |
| **Doctor** | Handle SOS alerts (dispatch the ambulance, resolve, log a check-in), look up patients, issue digital prescriptions with **tests referred**, scan paper prescriptions, view pharmacy stock (read-only) |
| **Pharmacist** | Run the pharmacy: add, edit and remove medicines with full details (generic name, strength, manufacturer, batch, **expiry date**), dispense and restock, act on notices from admin |
| **Admin** | Manage users, approve student ID cards, watch **pharmacy stock alerts** (low stock and expiry) and notify the pharmacist, forward custom-medicine requests |
| **Super Admin** | Everything an admin can do, plus manage admins and read feedback and bug reports. For privacy, there is no access to other users' portals. |

Every signed-in user can send **feedback or a bug report** to the super admin from the top bar.

## Features

- **Emergency SOS**: one tap sends the student's hall, room, symptom and emergency contact to the doctors.
  - Each patient has at most one active alert.
  - New alerts pulse on the doctor dashboard.
  - Ambulance: **01945678934**.
- **Digital prescriptions**:
  - The doctor picks medicines from pharmacy stock or types a custom one. Custom and out-of-stock medicines are reported to admin.
  - The doctor can add **tests referred** (common tests or custom ones).
  - Drug-allergy warnings appear while writing.
  - Each prescription exports as a PDF, which the patient can download.
- **Doctor view of a patient**: recent prescriptions first, then the student's latest upload grouped by medications,
  conditions, surgeries and summary, then the full searchable timeline.
- **AI medical history**: students upload photos or PDFs of old prescriptions, and Gemini (with an OpenRouter fallback) extracts
  medications, diagnoses and allergies.
- **Pharmacy**:
  - Live stock in Firestore, low-stock and expiry badges.
  - Stock changes are atomic, so two devices dispensing at once can't overwrite each other.
  - Admins see alerts and can notify the pharmacist.
- **Student ID verification**: new students upload their ID card. An AI pre-check runs, then an admin approves.
- **Blood bank**: a directory of voluntary donors.
- Responsive Material 3 UI for phone, tablet and desktop, with subtle animations that respect the "reduce motion" setting.

## Tech stack

Flutter (web, Android, iOS, desktop) · Riverpod · Firebase Auth, Cloud Firestore, Storage and Hosting ·
Gemini / OpenRouter vision AI · `pdf` + `printing` for prescriptions.

## Project structure

```
lib/
  app.dart                     role-based routing
  core/                        theme, constants, shared widgets (drawer, animations, responsive)
  features/
    auth_rbac/                 login, sign-up, roles, email + ID verification
    dashboard/                 student dashboard, medical history
    emergency_sos/             SOS trigger
    medical_operations/        doctor dashboard, prescriptions, pharmacy, check-in log
    medical_onboarding_ai/     AI document extraction
    admin_portal/              admin console, users, ID review, stock alerts, feedback
    blood_bank/                donor directory
firestore.rules                security rules (role-based)
test/                          widget and unit tests
```

## Getting started

```bash
flutter pub get
cp .env.example .env        # fill in GEMINI_API_KEY_1 / ALT_AI_API_KEY (the build needs this file)
flutter run -d chrome
```

Optional local emulators:

```bash
firebase emulators:start
node scripts/seed_emulator.js
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

## Deploying (Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting                 # app
firebase deploy --only firestore:rules         # when firestore.rules changes
```

Hosting settings (SPA rewrites, security headers, cache rules) are in `firebase.json`.

> **Security note:** the web build bundles `.env`, so any AI key in it is publicly readable. Use restricted keys,
> rotate them regularly, and move AI calls to a Cloud Function for production.

## Testing

```bash
flutter analyze
flutter test        # 143 tests
```

## Credits

- **Md. Sajol Hassan**: Lead Software Engineer & System Architect, Dept. of CSE, BAUST
- **Abdullah Al Galib Tonmoy**: Developer
- **Dr. Md Nakib Hayat Chowdhury**: Academic Advisor & Project Patron, Head of CSE, BAUST
- **BAUST Medical Center**: clinical consultation

Bangladesh Army University of Science and Technology (BAUST), Saidpur Cantonment, Nilphamari, Bangladesh ·
[www.baust.edu.bd](https://www.baust.edu.bd)
