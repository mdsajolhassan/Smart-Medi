# Smart Medi — Phase 1 Hardened Security & RBAC Guide

This document defines the audited Phase 1 security architecture, Firestore access control rules, zero-trust client enforcement, role management procedures, emulator unit test results, and local development emulator setup for **Smart Medi (BAUST Healthcare, Emergency SOS & Blood Directory)**.

---

## 1. Collection Coverage Audit & Hardened Rules Table

Every Firestore collection referenced in the codebase has been audited and mapped to an explicit rule in `firestore.rules`. The default-deny fallback ensures no unmapped path is accessible.

| Collection Path | Who Reads | Who Writes | Security Rule & Policy |
|---|---|---|---|
| `/users/{uid}` | Owner (`isOwner(uid)`) | **Create**: Owner only, `role: 'student'`, `bloodGroupVerified: false`, `approved: false`, `verificationStatus: 'verified'` iff university domain (`isUniEmail()`).<br>**Update**: Owner only, cannot touch protected fields (`role`, `verificationStatus`, `bloodGroupVerified`, `emailType`, `approved`, `uid`, `email`).<br>**Delete**: Denied (`false`). | Prevents client-side privilege escalation and look-alike domain spoofing. Initial profile created upon sign-up before email verification (`isMember()` is not required on initial create). |
| `/medical_histories/{uid}` | Owner (`isOwner(uid) && isMember()`) & Doctors (`isDoctor()`).<br>**Admin/VC explicitly DENIED.** | **Create**: Owner only, `isMember()`, `bloodGroupVerified: false`.<br>**Update**: Owner only, `isMember()`, cannot mutate `bloodGroupVerified` (`!affectedKeys().hasAny(['bloodGroupVerified'])`).<br>**Delete**: Denied (`false`). | Protects patient clinical privacy. **Split create/update solves the merge trap** so doctor-verified patients are never locked out of updating allergies/histories. |
| `/students/{uid}` | Owner (`isOwner(uid) && isMember()`) & Doctors (`isDoctor()`).<br>**Admin/VC explicitly DENIED.** | **Create**: Owner only, `isMember()`, `bloodGroupVerified: false`.<br>**Update**: Owner only, `isMember()`, cannot mutate `bloodGroupVerified`.<br>**Delete**: Denied (`false`). | Mirrored student profile with merge trap prevention. |
| `/student_ids/{id}` | Verified members (`isMember() && (resource == null \|\| resource.data.uid == auth.uid)`). | **Create**: Verified member, keys strictly limited to `['uid', 'createdAt']` and `uid == auth.uid`.<br>**Update/Delete**: Denied (`false`). | Transactional claim prevents duplicate student ID registrations. Unclaimed doc is readable inside the transaction; reading another's claimed ID is denied. |
| `/blood_donors/{uid}` | Verified members (`isMember()`). | **Create/Update**: Owner only (`isOwner(uid) && isMember()`).<br>Strict schema validation: `['uid', 'name', 'displayName', 'bloodGroup', 'bloodGroupVerified', 'department', 'hall', 'isAvailable', 'available', 'updatedAt', 'phone']`, `bloodGroupVerified == false`, `uid == uid`.<br>**Extra fields (allergies, medications, conditions, studentRoll) REJECTED.**<br>**Delete**: Owner only (`isMember()`). | Minimal public directory. Personal phone hidden unless explicitly opted in. |
| `/emergency_alerts/{alertId}` | Alert owner (`isMember() && studentId == auth.uid`), Doctors (`isDoctor()`), Admins (`isAdmin()`). | **Create**: Alert owner only (`isMember() && studentId == auth.uid`).<br>Snapshot field `emergencyContact` (`name`, `phone`, `relationship`) included at trigger time.<br>**Update**: Doctors & Admins only (for acknowledging, ambulance dispatch, resolving).<br>**Delete**: Denied (`false`). | Real-time campus SOS dispatch. Emergency contacts snapshotted so attending staff never need read access to `/emergency_contacts`. |
| `/emergency_contacts/{uid}` (and subcollections) | Owner only (`isOwner(uid) && isMember()`). | Owner only (`isOwner(uid) && isMember()`).<br>Strict schema validation: `['primaryContact', 'secondaryContact', 'name', 'relationship', 'phone', 'updatedAt']`. | Personal emergency contact records; strictly private to the student owner. |
| `/inventory/{itemId}` | Verified members (`isMember()`). | Medical staff (`isDoctor()`, `isAdmin()`, `isPharmacist()`). | Dispensary medicine stock catalog. |
| `/sick_leaves/{leaveId}` | Patient owner (`isMember() && studentId == auth.uid`), Doctors, Admins. | Doctors only (`isDoctor()`). | Medical leave certificates. |
| `/faculty/{facultyId}` | Doctors, Admins (`isDoctor()`, `isAdmin()`). | **Denied to all clients** (`false`). Only Server/Admin SDK/Console. | Institutional staff directory. |
| `All other paths` (`/{document=**}`) | **DENIED** (`false`) | **DENIED** (`false`) | Global zero-trust default deny. |

---

## 2. Helper Functions in `firestore.rules`

```javascript
// Institutional member: email verified, user doc exists, and verificationStatus == 'verified'
function isMember() {
  return emailVerified()
    && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && userDoc(request.auth.uid).verificationStatus == 'verified';
}

function isDoctor() {
  return emailVerified()
    && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && userDoc(request.auth.uid).role == 'doctor'
    && userDoc(request.auth.uid).get('approved', false) == true;
}

function isAdmin() {
  return emailVerified()
    && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && (userDoc(request.auth.uid).role == 'admin' || userDoc(request.auth.uid).role == 'superadmin')
    && userDoc(request.auth.uid).get('approved', false) == true;
}

function isPharmacist() {
  return emailVerified()
    && exists(/databases/$(database)/documents/users/$(request.auth.uid))
    && userDoc(request.auth.uid).role == 'pharmacist'
    && userDoc(request.auth.uid).get('approved', false) == true;
}
```

---

## 3. Local Development, Emulator Mode & Seed Data

### Starting Local Emulators
In project root:
```bash
firebase emulators:start
```
Starts:
- **Firestore Emulator**: `127.0.0.1:8080`
- **Auth Emulator**: `127.0.0.1:9099`

### Seeding Test Accounts
In a separate terminal:
```bash
node scripts/seed_emulator.js
```
This automatically seeds the following accounts (Password: `password123` for all):

| Email | Role | Verification | Description |
|---|---|---|---|
| `student@baust.edu.bd` | `student` | Verified | Tanvir Rahman (CSE, AUAH, willing blood donor, emergency contact seeded) |
| `second.student@baust.edu.bd` | `student` | Verified | Sadia Nusrat (EEE, BPTBH) |
| `doctor@baust.edu.bd` | `doctor` | Verified, `approved: true` | Dr. Md Nakib Hayat (Attending Campus Doctor) |
| `admin@baust.edu.bd` | `admin` | Verified, `approved: true` | Vice Chancellor / Admin |
| `pharmacist@baust.edu.bd` | `pharmacist` | Verified, `approved: true` | Campus Pharmacist (inventory manager) |
| `user@gmail.com` | `student` | `verificationStatus: 'pending'` | Personal email applicant (restricted from member collections) |

### Running Flutter App against Local Emulators
Run with `--dart-define=USE_EMULATORS=true` (guarded by `kDebugMode`, inactive in release builds):
```bash
# Web
flutter run -d chrome --dart-define=USE_EMULATORS=true

# Windows desktop
flutter run -d windows --dart-define=USE_EMULATORS=true
```

You can now test the complete end-to-end flow locally:
1. **Student Sign-in**: Log in as `student@baust.edu.bd` / `password123`.
2. **Profile Setup**: View pre-seeded profile or update student ID/roll.
3. **AI Medical Onboarding**: Upload medical lab reports and save summary.
4. **Blood Donor Directory**: Filter and search donors (`blood_donors`).
5. **Emergency SOS**: Press SOS panic button; view created alert with snapshotted emergency contacts.
6. **Doctor Sign-in**: Log in as `doctor@baust.edu.bd` / `password123` to view incoming SOS alerts, patient medical histories, and grant sick leaves.

---

## 4. Firebase Emulator Security Rules Test Results

Run all rules tests via:
```bash
firebase emulators:exec --only firestore --project smart-medi-b25ef "npm --prefix rules_tests test"
```

### Real Test Output (16 Passing)
```text
  Smart Medi Firestore Security Rules Unit Tests (Phase 1 Second Hardening Pass)
    √ 1. Unauthenticated access is DENIED everywhere (439ms)
    √ 2. Unverified account claiming a student_id is DENIED (134ms)
    √ 3. Reading non-existent student_ids doc inside claim transaction by verified member is ALLOWED (93ms)
    √ 4. Reading another user's claimed student_ids doc is DENIED (48ms)
    √ 5. student_ids duplicate claim fails (74ms)
    √ 6. Verified Gmail account with verificationStatus 'pending' is DENIED on member collections (103ms)
    √ 7. Doctor with approved: false is DENIED doctor privileges (58ms)
    √ 8. Admin with approved: false is DENIED admin privileges (48ms)
    √ 9. Pharmacist with approved: false is DENIED inventory write (40ms)
    √ 10. Admin cannot read individual patient medical_histories even when approved (48ms)
    √ 11. Creating an emergency_alert with someone else's studentId is DENIED (42ms)
    √ 12. Extra fields rejected in emergency_alerts (40ms)
    √ 13. Extra fields rejected in emergency_contacts (46ms)
    √ 14. blood_donors rejects extra fields (allergies, studentRoll) (48ms)
    √ 15. Real app payloads contract check (users, students, medical_histories, sos alert with snapshot contact) (66ms)
    √ 16. Doctor verifies bloodGroupVerified: true without locking student out of subsequent updates (Merge Trap Prevention) (66ms)

  16 passing (3s)
```

---

## 5. Firebase Project Environment (.firebaserc)

- `.firebaserc` points to:
  - `default`: `smart-medi-b25ef`
  - `dev`: `smart-medi-b25ef`
- `smart-medi-b25ef` is the **DEV / Sandbox test project**.
- Production project rules deployment is deferred until formal production project confirmation.
