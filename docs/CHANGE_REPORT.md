# Smart Medi — Upgrade Report (November 2026)

This report records every change made in this upgrade: AI provider, bug fixes, UI redesign,
the 4-role access model, student ID verification, profile editing, and the move to a new Firebase project.

---

## 1. Firebase project

| | Before | After |
|---|---|---|
| Project | `smart-medi-b25ef` (other account) | **`smart-medi-galib`** |
| Firestore | — | `(default)` database, rules deployed |
| Auth | — | Email/Password + Google |

* `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
  `.firebaserc`, `firebase.json`, `scripts/seed_emulator.js` all point to the new project.
* Bootstrap super admin (Google sign-in): `serviceprovidergalib@gmail.com` (`AuthConfig.superAdminEmail` + `firestore.rules`).
* All hard-coded people (old super admin, sample students/staff with real names, phone numbers and emails) were removed
  from the app. Account lists now come only from Firestore.

### Demo accounts
Created with `scripts/seed_demo_users.js` (uses your `firebase login`; passwords are read from environment variables and are **not** stored in the repo):

| Role | Login |
|---|---|
| Super Admin | `superadmin.demo@baust.edu.bd` |
| Admin | `admin.demo@baust.edu.bd` |
| Doctor | `doctor.demo@baust.edu.bd` |
| Student | `0802420205109001` (or `0802420205109001@baust.edu.bd`) |

```
DEMO_PW_SUPERADMIN=... DEMO_PW_ADMIN=... DEMO_PW_DOCTOR=... DEMO_PW_STUDENT=... node scripts/seed_demo_users.js smart-medi-galib
```
Re-running resets the demo accounts. Passwords are kept privately (not in git).

---

## 2. Roles & permissions (4-role model)

| Role | Home screen | Can do |
|---|---|---|
| **Student** | SOS / profile / blood bank / history | Own data only; must pass ID verification first |
| **Doctor** | Doctor dashboard | Clinical work. Legacy `nurse`, `pharmacist`, `medical_assistant`, `medical_officer` map here |
| **Admin** | Admin Console | Add / remove / restore **students & doctors**, change their role, approve student IDs |
| **Super Admin** | Super Admin Console | Everything an admin can + add/remove **admins**, read **feedback & bug reports**, control center |

Privacy guarantees (enforced in `firestore.rules`, not just the UI):
* The old global "super admin can read/write everything" rule was **removed**.
* Admins/super admins are **not** medical staff: no access to medical histories or prescriptions.
* No impersonation: the "Switch Role / Test View" tool and the debug "Dev Sandbox" login chips were removed.
* Admins never see or set passwords. Manually added users get a random throwaway password and a
  password-reset email so they choose their own.
* Admins cannot manage themselves or super admins; only super admins manage admins.
* "Remove user" is a soft delete (`accountStatus: removed`) → the user sees "Account deactivated" and rules block access.
  Deleting the Firebase Auth record itself requires the Admin SDK (Cloud Function, Blaze plan).

New screens: `AdminConsoleScreen`, `UserManagementScreen` (search, role filters, add/remove/restore, role change),
`FeedbackInboxScreen` (super admin), `SendFeedbackScreen` (everyone, in the drawer), `AccountRemovedScreen`.

---

## 3. Student ID verification (new students)

Flow: **Sign up → Profile setup → Upload student ID card → Admin approves → Medical onboarding → Dashboard**

* `StudentIdVerificationScreen`: camera/gallery upload, tips, AI pre-check, pending / rejected states,
  auto-refresh when an admin decides.
* AI pre-check (`GeminiAiService.analyzeStudentIdCard` + `compareIdCardWithProfile`) reads the card and checks:
  is it a BAUST student ID, does the name match, does the student ID match. Advisory only — an admin decides.
* `IdVerificationReviewScreen`: pending / verified / rejected queues, zoomable photo, AI summary,
  approve or reject with a reason shown to the student.
* Photos are compressed (≤ 650 KB) and stored in Firestore `id_verifications/{uid}` (free Spark plan, no Cloud Storage).
  The photo is deleted after approval.
* Existing students who had already completed onboarding are not locked out.
* Rules: students can only set their status to `pending`; only admins can set `verified` / `rejected`.

---

## 4. Profile editing

`EditProfileScreen` (drawer, profile tab, doctor header, ID screen) with role-aware sections:
* **Students:** name, phone, department, level, term, hall/room or home address (day scholar), self-reported blood group
  (locked once verified by the Medical Center), blood-donor opt-in. **Student ID is read-only.**
* **Doctors:** name, phone, designation, BMDC registration number (validated), department.
* Unsaved-changes guard; Bangladeshi phone validation.

---

## 5. AI prescription & handwriting reading

* New **alternative vision API**: `AlternativeVisionAiService` (OpenAI-compatible; default OpenRouter free models
  `nvidia/nemotron-3.5-super-vl:free`, `google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`, `openrouter/free`).
* **Automatic failover:** OpenRouter first → Gemini (key rotation + 4-model chain). When the OpenRouter daily free quota
  runs out, it is skipped until reset so scans go straight to Gemini.
* Prompt now knows Bangladeshi prescription conventions (`1+0+1`, BD/TDS/HS, Tab./Cap./Syp., খাবারের পরে, local brands).
* Per-medicine **instructions** are now extracted and filled in.
* Config in `.env` (see `.env.example`): `ALT_AI_API_KEY`, `ALT_AI_MODELS`, `ALT_AI_BASE_URL`, `AI_PRIMARY_PROVIDER`, `GEMINI_API_KEY_n`.

---

## 6. Bugs fixed

| Bug | Effect |
|---|---|
| Medicine-row text controllers disposed while still on screen (scan / delete row) | "used after being disposed" errors |
| Follow-up date picker opened on an AI-extracted past date | App crashed on "Change Date" |
| Medicine instructions never extracted | Instructions field always empty |
| Onboarding waited 1.6 s before calling the AI | Slower analysis |
| AI JSON wrapped in prose failed to parse | "Could not be formatted" errors |
| `.env` listed as an asset but git-ignored | Fresh clones could not build — now `cp .env.example .env` |
| Profile update wrote to `students/` for doctors and stamped hall/room on staff | Doctor profile saves failed under the rules |
| Login footer row overflowed on narrow screens | Layout overflow on small phones |
| Admin console / profile chips overflowed on phones | Layout overflow |
| Debug login chips and role switcher let anyone pose as super admin | Security hole |

---

## 7. UI redesign

* **Purple theme** (`BaustColors` palette + `AppTheme`): violet primary, fuchsia accent, rounded Material 3 components,
  floating snackbars, smooth page transitions, Bengali font fallback.
* **Responsive:** navigation rail on tablets/desktops (≥ 840 px, extended ≥ 1200 px) for student and doctor dashboards;
  width-capped content on every form/list screen; responsive grids; text scaling clamped (0.85–1.3×).
* Modern scan flow: bottom sheet (camera / gallery / files), animated AI progress checklist, result summary card.

---

## 8. Tests

`flutter test` → **138 tests pass**, `dart analyze` → no issues. New test files:
`alternative_vision_ai_test.dart`, `edit_profile_screen_test.dart`, `student_id_verification_test.dart`,
`four_roles_admin_test.dart`, `responsive_layout_test.dart` (no overflow at 320 px → 1440 px).

Firestore rules unit tests (`rules_tests/`) need the emulator: `firebase emulators:exec --only firestore "npm --prefix rules_tests test"`
— they were not re-run in this upgrade and some cases still assume the old global super-admin bypass.

---

## 9. Known limitations / next steps

* `.env` (AI keys) is bundled into the web/app build — move AI calls to a Cloud Function before public release.
* Firebase Auth records of removed users still exist (soft delete); full deletion needs the Admin SDK.
* Update `rules_tests/` for the new role model.

---

## 10. Deployment status

**GitHub:** PR #10 merged into `main` on 24 Nov 2026 (`e14d2f2`).

**Live on Firebase Hosting (25 Nov 2026):** https://smart-medi-galib.web.app
* Vercel was dropped: `vercel.json` is removed, and its rewrites and security headers now live in the `hosting`
  section of `firebase.json`.
* The cache lifetime for `/assets/**` is now 1 day. It was 1 year (immutable), which Flutter's unhashed asset names
  don't allow. `/`, `index.html`, `main.dart.js` and the service worker are never cached.
* Firestore rules are deployed from `firestore.rules`.

**To redeploy:**
```
flutter build web --release
firebase deploy --only hosting        # add firestore:rules when the rules change
```
The build needs a local `.env` (it is bundled as an asset; `.env` is git-ignored).

**Known risk (accepted for now):** `.env` is published with the site, so the Gemini and OpenRouter keys can be read
at `/assets/.env`. Rotate those keys and move AI calls to a Cloud Function (needs the Blaze plan) so that the keys
stay on the server.

---

## 11. Update — 25 Nov 2026

**Roles:** a new **pharmacist** role now runs the pharmacy. Admins create pharmacists in User Management. Doctors and admins see stock read-only.

**Doctor:**
* Each SOS alert can be logged to the check-in log only once.
* Resolving an alert closes every open alert for that patient.
* The patient report is grouped: recent prescriptions, recent upload, then the full timeline.
* Prescriptions support pharmacy-stock picking, custom medicines (reported to admin) and tests referred.
* Patients can download prescriptions as PDF.

**Pharmacy:**
* Each medicine records full details, including expiry date and batch.
* Pharmacists can add, edit and remove medicines.
* Stock updates are atomic.
* Admins see a Stock Alerts screen (low stock or expiry) and can notify the pharmacist.

**SOS:**
* Each patient has at most one active alert.
* A repeat press within 15 minutes of an alert no doctor has acted on yet updates that alert.
* The super admin's SOS testing monitor is removed.

**Privacy and UI:**
* The super admin can no longer open other users' portals.
* The feedback / bug report button is now on every role's top bar.
* Google sign-in is removed.
* Sign-out now returns to the login screen immediately.
* Animations added.

**Fixes from a full code review:**
* Pharmacy stock can no longer be re-seeded by accident or lose concurrent changes.
* Out-of-stock medicines are flagged.
* Duplicate medications no longer show in the doctor view.
* Environmental allergies are no longer dropped.
* The ID card check requires the full roll number.

**Hosting:** moved from Vercel to Firebase Hosting (https://smart-medi-galib.web.app). `vercel.json` is removed, along with the outdated `README_PHASE1_SECURITY.md` and `PROJECT_DOCUMENTATION.md`.

**Tests:** 143 passing.
