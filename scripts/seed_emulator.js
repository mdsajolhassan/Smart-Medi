/**
 * Smart Medi — Firebase Emulator Seed Script (Phase 1 Hardening)
 *
 * Seeds test users, roles, and initial collections into local Firebase Emulators:
 * - student@baust.edu.bd (verified, CSE, AUAH, willing blood donor)
 * - second.student@baust.edu.bd (verified, EEE, BPTBH)
 * - doctor@baust.edu.bd (verified, role: doctor, approved: true)
 * - admin@baust.edu.bd (verified, role: admin, approved: true)
 * - pharmacist@baust.edu.bd (verified, role: pharmacist, approved: true)
 * - user@gmail.com (personal email, verificationStatus: pending)
 *
 * Password for all accounts: password123
 */

const { initializeTestEnvironment } = require('../rules_tests/node_modules/@firebase/rules-unit-testing');

const PROJECT_ID = 'smart-medi-b25ef';
const AUTH_HOST = 'http://127.0.0.1:9099';
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;

const SEED_USERS = [
  {
    uid: 'student_1',
    email: 'student@baust.edu.bd',
    password: 'password123',
    displayName: 'Tanvir Rahman',
    emailVerified: true,
    role: 'student',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: false,
    bloodGroupVerified: false,
    department: 'Computer Science & Engineering (CSE)',
    studentRoll: '210401050',
    residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
    isWillingToDonateBlood: true,
  },
  {
    uid: 'student_2',
    email: 'second.student@baust.edu.bd',
    password: 'password123',
    displayName: 'Sadia Nusrat',
    emailVerified: true,
    role: 'student',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: false,
    bloodGroupVerified: false,
    department: 'Electrical & Electronic Engineering (EEE)',
    studentRoll: '210402015',
    residentialHall: 'Bir Protik Taramon Bibi Hall (BPTBH)',
    isWillingToDonateBlood: false,
  },
  {
    uid: 'doctor_1',
    email: 'doctor@baust.edu.bd',
    password: 'password123',
    displayName: 'Dr. Md Nakib Hayat',
    emailVerified: true,
    role: 'doctor',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: true,
    bloodGroupVerified: false,
  },
  {
    uid: 'admin_1',
    email: 'admin@baust.edu.bd',
    password: 'password123',
    displayName: 'Vice Chancellor / Admin',
    emailVerified: true,
    role: 'admin',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: true,
    bloodGroupVerified: false,
  },
  {
    uid: 'pharmacist_1',
    email: 'pharmacist@baust.edu.bd',
    password: 'password123',
    displayName: 'Campus Pharmacist',
    emailVerified: true,
    role: 'pharmacist',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: true,
    bloodGroupVerified: false,
  },
  {
    uid: 'gmail_pending_1',
    email: 'user@gmail.com',
    password: 'password123',
    displayName: 'Pending Applicant',
    emailVerified: true,
    role: 'student',
    verificationStatus: 'pending',
    emailType: 'personal',
    approved: false,
    bloodGroupVerified: false,
  },
  {
    uid: 'pending_doc_1',
    email: 'pending_doc@gmail.com',
    password: 'password123',
    displayName: 'Pending Doctor Applicant',
    emailVerified: true,
    role: 'student',
    verificationStatus: 'pending',
    emailType: 'personal',
    approved: false,
    bloodGroupVerified: false,
  },
  {
    uid: 'student_sajol',
    email: '0802420205101137@baust.edu.bd',
    password: 'password123',
    displayName: 'MD. Sajol Hassan (TEST)',
    emailVerified: true,
    role: 'student',
    verificationStatus: 'verified',
    emailType: 'university',
    approved: false,
    bloodGroupVerified: false,
    department: 'Computer Science & Engineering (CSE)',
    studentRoll: '0802420205101137',
    residentialHall: 'Zikrula Haque Hall',
    isWillingToDonateBlood: true,
  },
];

async function seedAuthUser(user) {
  try {
    // 1. Sign up user via Auth emulator endpoint
    const signupRes = await fetch(`${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: user.email,
        password: user.password,
        returnSecureToken: true,
      }),
    });
    const signupData = await signupRes.json();
    const idToken = signupData.idToken;

    if (idToken && user.emailVerified) {
      // 2. Mark email verified if required
      await fetch(`${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-key`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          idToken,
          displayName: user.displayName,
          emailVerified: user.emailVerified,
          returnSecureToken: true,
        }),
      });
    }
    console.log(`  [Auth] Created account: ${user.email} (Password: ${user.password})`);
  } catch (err) {
    console.warn(`  [Auth Notice] User ${user.email} creation: ${err.message}`);
  }
}

async function run() {
  console.log('===============================================================');
  console.log('Smart Medi — Seeding Local Firebase Emulators');
  console.log('===============================================================');

  // Seed Auth accounts
  console.log('\n1. Seeding Firebase Auth Emulator accounts...');
  for (const u of SEED_USERS) {
    await seedAuthUser(u);
  }

  // Seed Firestore Documents
  console.log('\n2. Seeding Firestore collections...');
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: FIRESTORE_HOST,
      port: FIRESTORE_PORT,
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    for (const u of SEED_USERS) {
      await db.collection('users').doc(u.uid).set({
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        role: u.role,
        verificationStatus: u.verificationStatus,
        emailType: u.emailType,
        approved: u.approved,
        bloodGroupVerified: u.bloodGroupVerified,
        profileCompleted: u.role === 'student' ? true : false,
        department: u.department || null,
        studentRoll: u.studentRoll || null,
        residentialHall: u.residentialHall || null,
        createdAt: new Date(),
      });
    }

    // Seed student_1 additional documents for full flow
    await db.collection('students').doc('student_1').set({
      studentId: 'student_1',
      studentRoll: '210401050',
      displayName: 'Tanvir Rahman',
      department: 'Computer Science & Engineering (CSE)',
      level: 'Level 4',
      term: 'Term 1',
      residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
      phone: '01712345678',
      bloodGroup: 'B+',
      bloodGroupVerified: false,
      isWillingToDonateBlood: true,
      profileCompleted: true,
      onboardingStatus: 'COMPLETED',
      criticalFlags: ['Dust Allergy'],
      updatedAt: new Date(),
    });

    await db.collection('student_ids').doc('210401050').set({
      uid: 'student_1',
      createdAt: new Date(),
    });

    // Seed student_sajol (0802420205101137) documents
    await db.collection('students').doc('student_sajol').set({
      studentId: '0802420205101137',
      studentRoll: '0802420205101137',
      displayName: 'MD. Sajol Hassan (TEST)',
      department: 'Computer Science & Engineering (CSE)',
      level: 'Level 4',
      term: 'Term 2',
      residentialHall: 'Zikrula Haque Hall',
      phone: '01700000000',
      bloodGroup: 'B+',
      bloodGroupVerified: false,
      isWillingToDonateBlood: true,
      profileCompleted: true,
      onboardingStatus: 'COMPLETED',
      criticalFlags: ['Penicillin Allergy'],
      updatedAt: new Date(),
    });

    await db.collection('student_ids').doc('0802420205101137').set({
      uid: 'student_sajol',
      createdAt: new Date(),
    });

    await db.collection('medical_histories').doc('student_sajol').set({
      uid: 'student_sajol',
      studentId: '0802420205101137',
      knownAllergies: ['Penicillin Allergy (TEST)'],
      activeIssues: ['Mild Asthma (TEST)'],
      historicalProblems: ['Seasonal Allergic Rhinitis (TEST)'],
      clinicalSummary: 'TEST Medical History Record: Regular follow-up at BAUST Medical Center.',
      prescriptions: [
        {
          name: 'Salbutamol Inhaler (TEST)',
          prescribed_date: '2026-01-15',
          dosage: '100mcg',
          frequency: 'As needed',
          instructions: '2 puffs when wheezing',
          doctor: 'Dr. Fowzia Jahan',
        },
      ],
      surgeries: [],
      updatedAt: new Date(),
    });

    await db.collection('blood_donors').doc('student_1').set({
      uid: 'student_1',
      displayName: 'Tanvir Rahman',
      bloodGroup: 'B+',
      bloodGroupVerified: false,
      department: 'Computer Science & Engineering (CSE)',
      hall: 'Abbas Uddin Ahmed Hall (AUAH)',
      isAvailable: true,
      phone: '01712345678',
      updatedAt: new Date(),
    });

    await db.collection('emergency_contacts').doc('student_1').set({
      primaryContact: '01711223344',
      name: 'Md. Rafiqul Islam',
      relationship: 'Father',
      phone: '01711223344',
      updatedAt: new Date(),
    });

    // Seed Sample Dispensary Inventory
    await db.collection('inventory').doc('med_001').set({
      id: 'med_001',
      brandName: 'Napa 500mg',
      genericName: 'Paracetamol',
      dosageForm: 'TABLET',
      unit: 'Strips (10 tabs)',
      stockUnits: 1420,
      threshold: 200,
      rack: 'Rack A-1',
      updatedAt: new Date(),
    });

    await db.collection('inventory').doc('med_002').set({
      id: 'med_002',
      brandName: 'Ventolin Evohaler 100mcg',
      genericName: 'Salbutamol Inhaler',
      dosageForm: 'INHALER',
      unit: 'Inhaler Canister',
      stockUnits: 45,
      threshold: 100,
      rack: 'Rack Emergency-1',
    // Seed TEST Digital Prescription for student_sajol
    await db.collection('prescriptions').doc('test_prescription_1').set({
      studentUid: 'student_sajol',
      studentId: '0802420205101137',
      studentName: 'MD. Sajol Hassan (TEST)',
      doctorUid: 'doctor_1',
      doctorName: 'Dr. Md Nakib Hayat',
      doctorDesignation: 'Senior Medical Officer',
      diagnosis: 'Acute Upper Respiratory Tract Infection (TEST)',
      items: [
        {
          name: 'Napa 500mg',
          dose: '1 tablet',
          frequency: '1+0+1',
          duration: '3 days',
          instructions: 'Take after meals',
        },
        {
          name: 'Fexo 120mg',
          dose: '1 tablet',
          frequency: '0+0+1',
          duration: '5 days',
          instructions: 'At night',
        },
      ],
      advice: 'Drink warm water and avoid cold drinks.',
      followUpDate: new Date(Date.now() + 5 * 86400000),
      source: 'digital',
      createdAt: new Date(),
    });

    console.log('  [Firestore] Successfully seeded users, students, student_ids, blood_donors, emergency_contacts, inventory, prescriptions (TEST)!');
  });

  await testEnv.cleanup();
  console.log('\n✅ Seeding complete! You can now log into the app via local emulators.');
}

run().catch((err) => {
  console.error('Seeding error:', err);
  process.exit(1);
});
