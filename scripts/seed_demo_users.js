#!/usr/bin/env node
/**
 * Seeds the 4 Smart Medi demo accounts (super admin, admin, doctor, student)
 * into the real Firebase project using your Firebase CLI login (`firebase login`).
 *
 * Usage:  node scripts/seed_demo_users.js [projectId]
 * Passwords come from env vars DEMO_PW_SUPERADMIN / DEMO_PW_ADMIN / DEMO_PW_DOCTOR / DEMO_PW_STUDENT.
 * Safe to re-run: existing accounts are updated, not duplicated.
 */
const path = require('path');
const { execSync } = require('child_process');

const PROJECT = process.argv[2] || 'smart-medi-galib';
const npmRoot = execSync('npm root -g').toString().trim();
const ft = (m) => require(path.join(npmRoot, 'firebase-tools', 'lib', m));
const { requireAuth } = ft('requireAuth');
const { getAccessToken } = ft('apiv2');

const STUDENT_ID = '0802420205109001';

const DEMO = [
  {
    key: 'SUPERADMIN',
    email: 'superadmin.demo@baust.edu.bd',
    displayName: 'Demo Super Admin',
    profile: {
      role: 'superadmin',
      accessLevel: 'SuperAdmin',
      designation: 'Super Administrator',
      department: 'Central Administration',
      phone: '01700000001',
    },
  },
  {
    key: 'ADMIN',
    email: 'admin.demo@baust.edu.bd',
    displayName: 'Demo Admin',
    profile: {
      role: 'admin',
      designation: 'System Administrator',
      department: 'Central Administration',
      phone: '01700000002',
    },
  },
  {
    key: 'DOCTOR',
    email: 'doctor.demo@baust.edu.bd',
    displayName: 'Dr. Demo Doctor',
    profile: {
      role: 'doctor',
      designation: 'Medical Officer',
      bmdcRegistrationNumber: 'A-54321',
      department: 'BAUST Medical Center',
      phone: '01700000003',
    },
  },
  {
    key: 'STUDENT',
    // Students can also log in with just the student ID (the app appends @baust.edu.bd).
    email: `${STUDENT_ID}@baust.edu.bd`,
    displayName: 'Demo Student',
    profile: {
      role: 'student',
      studentRoll: STUDENT_ID,
      department: 'Computer Science & Engineering (CSE)',
      level: 'Level 3',
      term: 'Term 1',
      residencyStatus: 'residential',
      residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
      roomNumber: '214',
      district: 'Nilphamari',
      upazila: 'Saidpur',
      phone: '01700000004',
      bloodGroup: 'B+',
      bloodGroupSource: 'self_reported',
      isWillingToDonateBlood: true,
      idVerificationStatus: 'verified',
    },
  },
];

let token;
async function call(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'x-goog-user-project': PROJECT,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (!res.ok) {
    const err = new Error(`${method} ${url} -> ${res.status}: ${json.error?.message || text}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

// --- Firestore REST value encoding
function enc(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, enc(x)])) } };
}
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const setDoc = (docPath, data) =>
  call('PATCH', `${FS}/${docPath}`, { fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, enc(v)])) });

const IDT = `https://identitytoolkit.googleapis.com`;

async function enableEmailPassword() {
  await call(
    'PATCH',
    `${IDT}/admin/v2/projects/${PROJECT}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`,
    { signIn: { email: { enabled: true, passwordRequired: true } } },
  );
}

async function upsertAuthUser(u, password) {
  try {
    const r = await call('POST', `${IDT}/v1/projects/${PROJECT}/accounts`, {
      email: u.email,
      password,
      displayName: u.displayName,
      emailVerified: true,
    });
    return r.localId;
  } catch (e) {
    if (!/EMAIL_EXISTS/.test(e.message)) throw e;
    const look = await call('POST', `${IDT}/v1/projects/${PROJECT}/accounts:lookup`, { email: [u.email] });
    const localId = look.users[0].localId;
    await call('POST', `${IDT}/v1/projects/${PROJECT}/accounts:update`, {
      localId,
      password,
      displayName: u.displayName,
      emailVerified: true,
      disableUser: false,
    });
    return localId;
  }
}

(async () => {
  const account = ft('auth').getGlobalDefaultAccount();
  if (!account) throw new Error('Run `firebase login` first.');
  await requireAuth({ user: account.user, tokens: account.tokens });
  token = await getAccessToken();

  console.log(`Project: ${PROJECT}`);
  await enableEmailPassword();
  console.log('✔ Email/password sign-in enabled');

  const now = new Date();
  for (const u of DEMO) {
    const password = process.env[`DEMO_PW_${u.key}`];
    if (!password) throw new Error(`Missing env DEMO_PW_${u.key}`);
    const uid = await upsertAuthUser(u, password);
    const isStudent = u.profile.role === 'student';

    await setDoc(`users/${uid}`, {
      uid,
      email: u.email,
      displayName: u.displayName,
      emailType: 'university',
      verificationStatus: 'verified',
      approved: !isStudent,
      accountStatus: 'active',
      bloodGroupVerified: false,
      profileCompleted: true,
      onboardingStatus: 'COMPLETED',
      isDemoAccount: true,
      createdAt: now,
      updatedAt: now,
      ...u.profile,
    });

    if (isStudent) {
      const p = u.profile;
      await setDoc(`student_ids/${p.studentRoll}`, { uid, createdAt: now });
      await setDoc(`students/${uid}`, {
        uid,
        displayName: u.displayName,
        email: u.email,
        studentRoll: p.studentRoll,
        studentId: p.studentRoll,
        department: p.department,
        level: p.level,
        term: p.term,
        residencyStatus: p.residencyStatus,
        residentialHall: p.residentialHall,
        roomNumber: p.roomNumber,
        phone: p.phone,
        bloodGroup: p.bloodGroup,
        bloodGroupSource: p.bloodGroupSource,
        bloodGroupVerified: false,
        criticalFlags: ['Penicillin'],
        onboardingStatus: 'COMPLETED',
        updatedAt: now,
      });
      await setDoc(`medical_histories/${uid}`, {
        studentId: uid,
        historicalProblems: ['Asthma (হাঁপানি) - mild, since 2015'],
        activeIssues: ['Seasonal allergic rhinitis'],
        knownAllergies: ['Penicillin'],
        bloodGroup: p.bloodGroup,
        bloodGroupSource: p.bloodGroupSource,
        bloodGroupVerified: false,
        confidenceScore: 0.9,
        clinicalSummary: 'Demo record: mild asthma controlled with inhaler as needed; penicillin allergy (rash).',
        procedures: [{ name: 'Appendectomy', date: '2019' }],
        prescriptions: [
          { name: 'Salbutamol Inhaler 100mcg', dose: '2 puffs', frequency: 'as needed', status: 'Ongoing / as needed' },
          { name: 'Tab. Fexo 120mg', dose: '1 tab', frequency: '0+0+1', duration_text: '14 days', status: 'Active' },
        ],
        isEligibleForBloodDonation: true,
        updatedAt: now,
      });
      await setDoc(`blood_donors/${uid}`, {
        uid,
        displayName: u.displayName,
        bloodGroup: p.bloodGroup,
        bloodGroupVerified: false,
        department: p.department,
        hall: p.residentialHall,
        isAvailable: true,
        phone: p.phone,
        updatedAt: now,
      });
      await setDoc(`emergency_contacts/${uid}`, {
        name: 'Demo Guardian',
        relationship: 'Father',
        phone: '01700000099',
        updatedAt: now,
      });
    }
    console.log(`✔ ${u.profile.role.padEnd(10)} ${u.email}  (uid ${uid})`);
  }
  console.log('Done.');
})().catch((e) => {
  console.error('✖', e.message);
  process.exit(1);
});
