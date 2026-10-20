const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const assert = require('assert');
const fs = require('fs');
const path = require('path');

let testEnv;

describe('Smart Medi Firestore Security Rules Unit Tests (Phase 1 Second Hardening Pass)', () => {
  before(async () => {
    const rulesPath = path.resolve(__dirname, '../firestore.rules');
    const rulesContent = fs.readFileSync(rulesPath, 'utf8');

    testEnv = await initializeTestEnvironment({
      projectId: 'smart-medi-test-proj',
      firestore: {
        rules: rulesContent,
        host: process.env.FIRESTORE_EMULATOR_HOST ? process.env.FIRESTORE_EMULATOR_HOST.split(':')[0] : '127.0.0.1',
        port: process.env.FIRESTORE_EMULATOR_HOST ? parseInt(process.env.FIRESTORE_EMULATOR_HOST.split(':')[1]) : 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  // 1. Unauthenticated access denied everywhere
  it('1. Unauthenticated access is DENIED everywhere', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('users').doc('stu1').get());
    await assertFails(unauthDb.collection('medical_histories').doc('stu1').get());
    await assertFails(unauthDb.collection('blood_donors').doc('stu1').get());
    await assertFails(unauthDb.collection('emergency_alerts').doc('alt1').get());
    await assertFails(unauthDb.collection('inventory').doc('med1').get());
    await assertFails(unauthDb.collection('student_ids').doc('210401050').get());
    await assertFails(unauthDb.collection('emergency_contacts').doc('stu1').get());
  });

  // 2. Unverified account claiming a student_id is DENIED
  it('2. Unverified account claiming a student_id is DENIED', async () => {
    // Unverified user doc
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('stu_unverified').set({
        uid: 'stu_unverified',
        role: 'student',
        verificationStatus: 'verified',
        email: 'unverified@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const unverifiedDb = testEnv.authenticatedContext('stu_unverified', {
      email: 'unverified@baust.edu.bd',
      email_verified: false,
    }).firestore();

    await assertFails(unverifiedDb.collection('student_ids').doc('210401050').set({
      uid: 'stu_unverified',
      createdAt: new Date(),
    }));
  });

  // 3. Reading non-existent student_ids inside claim transaction by member is ALLOWED
  it('3. Reading non-existent student_ids doc inside claim transaction by verified member is ALLOWED', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('stu_member').set({
        uid: 'stu_member',
        role: 'student',
        verificationStatus: 'verified',
        email: 'member@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const memberDb = testEnv.authenticatedContext('stu_member', {
      email: 'member@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Doc does not exist yet -> resource == null -> allowed
    await assertSucceeds(memberDb.collection('student_ids').doc('210401050').get());
  });

  // 4. Reading another user's claimed student_ids doc is DENIED
  it('4. Reading another user\'s claimed student_ids doc is DENIED', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('owner_stu').set({
        uid: 'owner_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'owner@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('other_stu').set({
        uid: 'other_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'other@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('student_ids').doc('210401050').set({
        uid: 'owner_stu',
        createdAt: new Date(),
      });
    });

    const otherDb = testEnv.authenticatedContext('other_stu', {
      email: 'other@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Reading owner's claimed ID document is DENIED
    await assertFails(otherDb.collection('student_ids').doc('210401050').get());
  });

  // 5. student_ids duplicate claim fails
  it('5. student_ids duplicate claim fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('stu1').set({
        uid: 'stu1',
        role: 'student',
        verificationStatus: 'verified',
        email: 'stu1@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('stu2').set({
        uid: 'stu2',
        role: 'student',
        verificationStatus: 'verified',
        email: 'stu2@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const stu1Db = testEnv.authenticatedContext('stu1', {
      email: 'stu1@baust.edu.bd',
      email_verified: true,
    }).firestore();

    const stu2Db = testEnv.authenticatedContext('stu2', {
      email: 'stu2@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // First student claims 210401050 -> SUCCEEDS
    await assertSucceeds(stu1Db.collection('student_ids').doc('210401050').set({
      uid: 'stu1',
      createdAt: new Date(),
    }));

    // Second student attempts to overwrite 210401050 -> DENIED
    await assertFails(stu2Db.collection('student_ids').doc('210401050').set({
      uid: 'stu2',
      createdAt: new Date(),
    }));
  });

  // 6. Verified Gmail account with verificationStatus 'pending' is DENIED on blood_donors, inventory, emergency_alerts, medical_histories
  it('6. Verified Gmail account with verificationStatus \'pending\' is DENIED on member collections', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('gmail_user').set({
        uid: 'gmail_user',
        role: 'student',
        verificationStatus: 'pending',
        emailType: 'personal',
        email: 'user@gmail.com',
        bloodGroupVerified: false,
      });
    });

    const gmailDb = testEnv.authenticatedContext('gmail_user', {
      email: 'user@gmail.com',
      email_verified: true,
    }).firestore();

    // Denied on blood_donors
    await assertFails(gmailDb.collection('blood_donors').doc('gmail_user').get());

    // Denied on inventory
    await assertFails(gmailDb.collection('inventory').doc('med_001').get());

    // Denied on emergency_alerts create
    await assertFails(gmailDb.collection('emergency_alerts').doc('alert_gmail').set({
      alertId: 'alert_gmail',
      studentId: 'gmail_user',
      studentName: 'Gmail User',
      studentEmail: 'user@gmail.com',
      studentRoll: 'N/A',
      department: 'General',
      advisorId: 'unassigned',
      hall: 'Day Scholar',
      roomNumber: '101',
      symptomCategory: 'Fever',
      optionalNote: '',
      criticalFlags: [],
      status: 'TRIGGERED',
      triggeredAt: new Date(),
      acknowledgedAt: null,
      acknowledgedByDoctorId: null,
    }));

    // Denied on medical_histories create
    await assertFails(gmailDb.collection('medical_histories').doc('gmail_user').set({
      studentId: 'gmail_user',
      bloodGroup: 'O+',
      bloodGroupVerified: false,
    }));
  });

  // 7. Doctor with approved: false is DENIED
  it('7. Doctor with approved: false is DENIED doctor privileges', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('unapproved_doc').set({
        uid: 'unapproved_doc',
        role: 'doctor',
        approved: false,
        verificationStatus: 'verified',
        email: 'doc.unapp@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('medical_histories').doc('patient_1').set({
        studentId: 'patient_1',
        bloodGroup: 'B+',
        bloodGroupVerified: false,
      });
    });

    const docDb = testEnv.authenticatedContext('unapproved_doc', {
      email: 'doc.unapp@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(docDb.collection('medical_histories').doc('patient_1').get());
  });

  // 8. Admin with approved: false is DENIED
  it('8. Admin with approved: false is DENIED admin privileges', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('unapproved_admin').set({
        uid: 'unapproved_admin',
        role: 'admin',
        approved: false,
        verificationStatus: 'verified',
        email: 'admin.unapp@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('emergency_alerts').doc('alt_1').set({
        alertId: 'alt_1',
        studentId: 'some_stu',
        status: 'TRIGGERED',
        triggeredAt: new Date(),
      });
    });

    const adminDb = testEnv.authenticatedContext('unapproved_admin', {
      email: 'admin.unapp@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Cannot update emergency alert status
    await assertFails(adminDb.collection('emergency_alerts').doc('alt_1').update({
      status: 'ACKNOWLEDGED',
    }));
  });

  // 9. Pharmacist with approved: false is DENIED
  it('9. Pharmacist with approved: false is DENIED inventory write', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('unapproved_pharm').set({
        uid: 'unapproved_pharm',
        role: 'pharmacist',
        approved: false,
        verificationStatus: 'verified',
        email: 'pharm.unapp@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const pharmDb = testEnv.authenticatedContext('unapproved_pharm', {
      email: 'pharm.unapp@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(pharmDb.collection('inventory').doc('med_001').set({
      brandName: 'Napa',
      stockUnits: 100,
    }));
  });

  // 10. Admin cannot read individual patient medical_histories even when approved
  it('10. Admin cannot read individual patient medical_histories even when approved', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('admin_approved').set({
        uid: 'admin_approved',
        role: 'admin',
        approved: true,
        verificationStatus: 'verified',
        email: 'vc@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('medical_histories').doc('patient_1').set({
        studentId: 'patient_1',
        bloodGroup: 'AB+',
        bloodGroupVerified: false,
      });
    });

    const adminDb = testEnv.authenticatedContext('admin_approved', {
      email: 'vc@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(adminDb.collection('medical_histories').doc('patient_1').get());
  });

  // 11. Creating an emergency_alert with someone else's studentId is DENIED
  it('11. Creating an emergency_alert with someone else\'s studentId is DENIED', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('caller_stu').set({
        uid: 'caller_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'caller@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const callerDb = testEnv.authenticatedContext('caller_stu', {
      email: 'caller@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Trying to create alert where studentId != caller_stu is DENIED
    await assertFails(callerDb.collection('emergency_alerts').doc('alt_spoof').set({
      alertId: 'alt_spoof',
      studentId: 'victim_stu', // SPOOFED
      studentName: 'Victim',
      studentEmail: 'victim@baust.edu.bd',
      studentRoll: '210401099',
      department: 'CSE',
      advisorId: 'unassigned',
      hall: 'AUAH',
      roomNumber: '101',
      symptomCategory: 'Fever',
      optionalNote: '',
      criticalFlags: [],
      status: 'TRIGGERED',
      triggeredAt: new Date(),
      acknowledgedAt: null,
      acknowledgedByDoctorId: null,
    }));
  });

  // 12. Extra fields rejected in emergency_alerts
  it('12. Extra fields rejected in emergency_alerts', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('sos_stu').set({
        uid: 'sos_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'sos@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const sosDb = testEnv.authenticatedContext('sos_stu', {
      email: 'sos@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Contains forbidden extra field 'hackerNote'
    await assertFails(sosDb.collection('emergency_alerts').doc('alt_extra').set({
      alertId: 'alt_extra',
      studentId: 'sos_stu',
      studentName: 'SOS Student',
      studentEmail: 'sos@baust.edu.bd',
      studentRoll: '210401050',
      department: 'CSE',
      advisorId: 'unassigned',
      hall: 'AUAH',
      roomNumber: '101',
      symptomCategory: 'Chest Pain',
      optionalNote: '',
      criticalFlags: [],
      status: 'TRIGGERED',
      triggeredAt: new Date(),
      acknowledgedAt: null,
      acknowledgedByDoctorId: null,
      hackerNote: 'FORBIDDEN FIELD', // FORBIDDEN
    }));
  });

  // 13. Extra fields rejected in emergency_contacts
  it('13. Extra fields rejected in emergency_contacts', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('contact_stu').set({
        uid: 'contact_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'contact@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const contactDb = testEnv.authenticatedContext('contact_stu', {
      email: 'contact@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Contains forbidden extra field 'nationalId'
    await assertFails(contactDb.collection('emergency_contacts').doc('contact_stu').set({
      primaryContact: '01711223344',
      name: 'Father',
      relationship: 'Parent',
      phone: '01711223344',
      nationalId: '1234567890', // FORBIDDEN
    }));
  });

  // 14. Blood_donors rejects extra fields (allergies, studentRoll)
  it('14. blood_donors rejects extra fields (allergies, studentRoll)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('donor_stu').set({
        uid: 'donor_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'donor@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const donorDb = testEnv.authenticatedContext('donor_stu', {
      email: 'donor@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Minimal allowed fields SUCCEEDS
    await assertSucceeds(donorDb.collection('blood_donors').doc('donor_stu').set({
      uid: 'donor_stu',
      displayName: 'Tanvir Rahman',
      bloodGroup: 'B+',
      bloodGroupVerified: false,
      department: 'CSE',
      hall: 'AUAH',
      isAvailable: true,
      updatedAt: new Date(),
      phone: '01712345678',
    }));

    // Extra fields (e.g. allergies, studentRoll) is DENIED
    await assertFails(donorDb.collection('blood_donors').doc('donor_stu').set({
      uid: 'donor_stu',
      displayName: 'Tanvir Rahman',
      bloodGroup: 'B+',
      bloodGroupVerified: false,
      department: 'CSE',
      hall: 'AUAH',
      isAvailable: true,
      updatedAt: new Date(),
      studentRoll: '210401050',
      allergies: ['Penicillin'],
    }));
  });

  // 15. Real app payloads contract check (Dart exact payloads)
  it('15. Real app payloads contract check (users, students, medical_histories, sos alert with snapshot contact)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc('real_stu').set({
        uid: 'real_stu',
        role: 'student',
        verificationStatus: 'verified',
        emailType: 'university',
        email: 'real@baust.edu.bd',
        bloodGroupVerified: false,
      });
    });

    const stuDb = testEnv.authenticatedContext('real_stu', {
      email: 'real@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Real SOS payload with snapshot emergency contact SUCCEEDS
    await assertSucceeds(stuDb.collection('emergency_alerts').doc('real_alt').set({
      alertId: 'real_alt',
      studentId: 'real_stu',
      studentName: 'Tanvir Rahman',
      studentEmail: 'real@baust.edu.bd',
      studentRoll: '210401050',
      department: 'Computer Science & Engineering (CSE)',
      advisorId: 'unassigned',
      hall: 'Abbas Uddin Ahmed Hall (AUAH)',
      roomNumber: '402',
      symptomCategory: 'Severe Asthma / Difficulty Breathing',
      optionalNote: 'Inhaler empty',
      criticalFlags: ['Dust Allergy'],
      status: 'TRIGGERED',
      triggeredAt: new Date(),
      acknowledgedAt: null,
      acknowledgedByDoctorId: null,
      emergencyContact: {
        name: 'Md. Rafiqul Islam',
        phone: '01711223344',
        relationship: 'Father',
      },
    }));

    // Real medical history payload from completeOnboarding SUCCEEDS
    await assertSucceeds(stuDb.collection('medical_histories').doc('real_stu').set({
      studentId: 'real_stu',
      historicalProblems: ['Asthma'],
      activeIssues: ['Wheezing'],
      knownAllergies: ['Dust'],
      bloodGroup: 'B+',
      bloodGroupSource: 'lab_report',
      bloodGroupVerified: false,
      confidenceScore: 0.95,
      clinicalSummary: 'Known asthma case',
      isEligibleForBloodDonation: true,
      bloodDonationIneligibilityReason: null,
      updatedAt: new Date(),
    }));

    // Real students mirrored profile payload SUCCEEDS
    await assertSucceeds(stuDb.collection('students').doc('real_stu').set({
      studentId: 'real_stu',
      studentRoll: '210401050',
      department: 'Computer Science & Engineering (CSE)',
      level: 'Level 4',
      term: 'Term 1',
      residentialHall: 'Abbas Uddin Ahmed Hall (AUAH)',
      phone: '01712345678',
      isWillingToDonateBlood: true,
      profileCompleted: true,
      onboardingStatus: 'COMPLETED',
      bloodGroup: 'B+',
      bloodGroupSource: 'lab_report',
      bloodGroupVerified: false,
      criticalFlags: ['Dust'],
      isEligibleForBloodDonation: true,
      bloodDonationIneligibilityReason: null,
      updatedAt: new Date(),
    }));
  });

  // 16. Doctor verifies bloodGroupVerified: true without locking student out of subsequent updates (Merge Trap Prevention)
  it('16. Doctor verifies bloodGroupVerified: true without locking student out of subsequent updates (Merge Trap Prevention)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('patient_stu').set({
        uid: 'patient_stu',
        role: 'student',
        verificationStatus: 'verified',
        email: 'patient@baust.edu.bd',
        bloodGroupVerified: false,
      });
      await db.collection('medical_histories').doc('patient_stu').set({
        studentId: 'patient_stu',
        bloodGroup: 'B+',
        bloodGroupVerified: false,
        allergies: ['Dust'],
      });
      // Doctor verifies the blood group
      await db.collection('medical_histories').doc('patient_stu').update({
        bloodGroupVerified: true,
      });
    });

    const studentDb = testEnv.authenticatedContext('patient_stu', {
      email: 'patient@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Student updates allergies without touching bloodGroupVerified -> SUCCEEDS!
    await assertSucceeds(studentDb.collection('medical_histories').doc('patient_stu').update({
      allergies: ['Dust', 'Pollen'],
    }));

    // Student attempting to tamper with bloodGroupVerified -> DENIED!
    await assertFails(studentDb.collection('medical_histories').doc('patient_stu').update({
      bloodGroupVerified: false,
    }));
  });

  // 17. SuperAdmin: email/password token (email_verified false) is DENIED; google.com verified token is ALLOWED
  it('17. SuperAdmin: email/password token (email_verified false) is DENIED; google.com verified token is ALLOWED', async () => {
    const unverifiedPasswordSuperAdminDb = testEnv.authenticatedContext('superadmin_uid', {
      email: 'mdsajolhasan5@gmail.com',
      email_verified: false,
      firebase: {
        sign_in_provider: 'password',
      },
    }).firestore();

    // Denied because not verified and not google.com
    await assertFails(unverifiedPasswordSuperAdminDb.collection('inventory').doc('med1').set({
      name: 'Napa',
      currentStock: 50,
    }));
    await assertFails(unverifiedPasswordSuperAdminDb.collection('users').doc('some_user').get());

    const verifiedGoogleSuperAdminDb = testEnv.authenticatedContext('superadmin_uid', {
      email: 'mdsajolhasan5@gmail.com',
      email_verified: true,
      firebase: {
        sign_in_provider: 'google.com',
      },
    }).firestore();

    // Allowed anywhere due to isSuperAdmin() override
    await assertSucceeds(verifiedGoogleSuperAdminDb.collection('inventory').doc('med1').set({
      name: 'Napa',
      currentStock: 50,
    }));
    await assertSucceeds(verifiedGoogleSuperAdminDb.collection('inventory').doc('med1').get());
  });

  // 18. Approved doctor can query students by studentId and read medical_histories
  it('18. Approved doctor can query students by studentId and read medical_histories', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // Setup approved doctor user doc
      await db.collection('users').doc('doctor_active').set({
        uid: 'doctor_active',
        role: 'doctor',
        email: 'doctor@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      // Setup student profile and medical history
      await db.collection('students').doc('student_sajol').set({
        studentId: '0802420205101137',
        studentRoll: '0802420205101137',
        displayName: 'MD. Sajol Hassan',
        department: 'Dept of CSE',
        bloodGroup: 'B+',
        bloodGroupVerified: false,
      });
      await db.collection('medical_histories').doc('student_sajol').set({
        studentId: 'student_sajol',
        bloodGroup: 'B+',
        knownAllergies: ['Dust Allergy'],
        clinicalSummary: 'Active student health record',
      });
    });

    const doctorDb = testEnv.authenticatedContext('doctor_active', {
      email: 'doctor@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Query students by studentId
    const querySnap = await doctorDb.collection('students').where('studentId', '==', '0802420205101137').get();
    assert.strictEqual(querySnap.docs.length, 1);
    assert.strictEqual(querySnap.docs[0].data().displayName, 'MD. Sajol Hassan');

    // Read student medical history doc
    await assertSucceeds(doctorDb.collection('medical_histories').doc('student_sajol').get());
  });

  // 19. Unapproved or pending doctor is DENIED access to students and medical_histories
  it('19. Unapproved or pending doctor is DENIED access to students and medical_histories', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doctor_pending').set({
        uid: 'doctor_pending',
        role: 'doctor',
        email: 'pending_doc@gmail.com',
        approved: false, // NOT approved
        verificationStatus: 'pending',
        bloodGroupVerified: false,
      });
    });

    const pendingDoctorDb = testEnv.authenticatedContext('doctor_pending', {
      email: 'pending_doc@gmail.com',
      email_verified: true,
    }).firestore();

    // Denied querying students
    await assertFails(pendingDoctorDb.collection('students').where('studentId', '==', '0802420205101137').get());
    // Denied reading medical history
    await assertFails(pendingDoctorDb.collection('medical_histories').doc('student_sajol').get());
  });

  // 20. Student cannot query another student in students collection
  it('20. Student cannot query another student in students collection', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('student_other').set({
        uid: 'student_other',
        role: 'student',
        email: 'other@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
    });

    const studentDb = testEnv.authenticatedContext('student_other', {
      email: 'other@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Querying another student's ID across students collection is DENIED
    await assertFails(studentDb.collection('students').where('studentId', '==', '0802420205101137').get());
    // Reading another student's medical history is DENIED
    await assertFails(studentDb.collection('medical_histories').doc('student_sajol').get());
  });

  // 21. Audit Trail access_logs: Doctor can create log with own uid; student cannot create; extra fields rejected
  it('21. Audit Trail access_logs: Doctor can create log with own uid; student cannot; extra fields rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doctor_active').set({
        uid: 'doctor_active',
        role: 'doctor',
        email: 'doctor@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('student_other').set({
        uid: 'student_other',
        role: 'student',
        email: 'other@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
    });

    const doctorDb = testEnv.authenticatedContext('doctor_active', {
      email: 'doctor@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Doctor creates valid audit log -> SUCCEEDS
    await assertSucceeds(doctorDb.collection('access_logs').doc('log_1').set({
      doctorUid: 'doctor_active',
      doctorName: 'Dr. Md Nakib Hayat',
      studentUid: 'student_sajol',
      studentId: '0802420205101137',
      action: 'view_history',
      createdAt: new Date(),
    }));

    // Doctor attempts to spoof doctorUid -> DENIED
    await assertFails(doctorDb.collection('access_logs').doc('log_spoof').set({
      doctorUid: 'another_doctor_uid',
      doctorName: 'Dr. Md Nakib Hayat',
      studentUid: 'student_sajol',
      studentId: '0802420205101137',
      action: 'view_history',
      createdAt: new Date(),
    }));

    // Extra unknown field -> DENIED
    await assertFails(doctorDb.collection('access_logs').doc('log_extra').set({
      doctorUid: 'doctor_active',
      doctorName: 'Dr. Md Nakib Hayat',
      studentUid: 'student_sajol',
      studentId: '0802420205101137',
      action: 'view_history',
      createdAt: new Date(),
      extraField: 'malicious_payload',
    }));

    // Student attempting to create access log -> DENIED
    const studentDb = testEnv.authenticatedContext('student_other', {
      email: 'other@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(studentDb.collection('access_logs').doc('log_student').set({
      doctorUid: 'student_other',
      doctorName: 'Student Impersonator',
      studentUid: 'student_sajol',
      studentId: '0802420205101137',
      action: 'view_history',
      createdAt: new Date(),
    }));
  });

  // 22. Super Admin can read access_logs; doctor and normal users are DENIED reading or updating access_logs
  it('22. Super Admin can read access_logs; doctor and normal users are DENIED reading or updating access_logs', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doctor_active').set({
        uid: 'doctor_active',
        role: 'doctor',
        email: 'doctor@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('access_logs').doc('log_1').set({
        doctorUid: 'doctor_active',
        doctorName: 'Dr. Md Nakib Hayat',
        studentUid: 'student_sajol',
        studentId: '0802420205101137',
        action: 'view_history',
        createdAt: new Date(),
      });
    });

    const doctorDb = testEnv.authenticatedContext('doctor_active', {
      email: 'doctor@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Doctor cannot read or update access_logs
    await assertFails(doctorDb.collection('access_logs').doc('log_1').get());
    await assertFails(doctorDb.collection('access_logs').doc('log_1').update({
      action: 'tampered_action',
    }));

    const superAdminDb = testEnv.authenticatedContext('superadmin_uid', {
      email: 'mdsajolhasan5@gmail.com',
      email_verified: true,
      firebase: {
        sign_in_provider: 'google.com',
      },
    }).firestore();

    // Super Admin can read access_logs
    await assertSucceeds(superAdminDb.collection('access_logs').doc('log_1').get());
    const allLogsSnap = await superAdminDb.collection('access_logs').get();
    assert.ok(allLogsSnap.docs.length >= 1);
  });

  // 23. Digital Prescriptions: Approved doctor can create; validations enforced; unapproved & students DENIED
  it('23. Digital Prescriptions: Approved doctor can create; validations enforced; unapproved & students DENIED', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doc_approved').set({
        uid: 'doc_approved',
        role: 'doctor',
        email: 'doc@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('doc_unapproved').set({
        uid: 'doc_unapproved',
        role: 'doctor',
        email: 'doc2@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('student_owner').set({
        uid: 'student_owner',
        role: 'student',
        email: 'stu@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
    });

    const doctorDb = testEnv.authenticatedContext('doc_approved', {
      email: 'doc@baust.edu.bd',
      email_verified: true,
    }).firestore();

    const validPrescription = {
      studentUid: 'student_owner',
      studentId: '210401050',
      studentName: 'Tanvir Rahman',
      doctorUid: 'doc_approved',
      doctorName: 'Dr. Md Nakib Hayat',
      doctorDesignation: 'Medical Officer',
      diagnosis: 'Acute Upper Respiratory Tract Infection',
      items: [
        {
          name: 'Amoxicillin 500mg',
          dose: '1 capsule',
          frequency: '1+1+1 (8 hourly)',
          duration: '7 days',
          instructions: 'Take after meals',
        },
      ],
      advice: 'Drink warm water and rest.',
      followUpDate: new Date(Date.now() + 7 * 86400000),
      source: 'digital',
      createdAt: new Date(),
    };

    // 1. Approved doctor creates valid prescription -> SUCCEEDS
    await assertSucceeds(doctorDb.collection('prescriptions').doc('rx_1').set(validPrescription));

    // 1b. Approved doctor creates valid scanned prescription (source: 'scan') -> SUCCEEDS
    await assertSucceeds(doctorDb.collection('prescriptions').doc('rx_scan').set({
      ...validPrescription,
      source: 'scan',
    }));

    // 1c. Invalid source string -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_bad_src').set({
      ...validPrescription,
      source: 'manual',
    }));

    // 2. Doctor cannot spoof another doctorUid -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_spoof').set({
      ...validPrescription,
      doctorUid: 'another_doctor_uid',
    }));

    // 3. Extra fields rejected -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_extra').set({
      ...validPrescription,
      extraUnauthorizedField: 'malicious',
    }));

    // 4. Empty items rejected (size < 1) -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_empty_items').set({
      ...validPrescription,
      items: [],
    }));

    // 5. Unapproved doctor -> DENIED
    const unapprovedDoctorDb = testEnv.authenticatedContext('doc_unapproved', {
      email: 'doc2@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(unapprovedDoctorDb.collection('prescriptions').doc('rx_unapproved').set({
      ...validPrescription,
      doctorUid: 'doc_unapproved',
    }));

    // 6. Student cannot create prescription -> DENIED
    const studentDb = testEnv.authenticatedContext('student_owner', {
      email: 'stu@baust.edu.bd',
      email_verified: true,
    }).firestore();

    await assertFails(studentDb.collection('prescriptions').doc('rx_student').set({
      ...validPrescription,
      doctorUid: 'student_owner',
    }));
  });

  // 24. Digital Prescriptions: Read permissions, immutability (no update/delete)
  it('24. Digital Prescriptions: Read permissions, immutability (no update/delete)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doc_active').set({
        uid: 'doc_active',
        role: 'doctor',
        email: 'doc@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('student_owner').set({
        uid: 'student_owner',
        role: 'student',
        email: 'owner@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('student_other').set({
        uid: 'student_other',
        role: 'student',
        email: 'other@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('prescriptions').doc('rx_test').set({
        studentUid: 'student_owner',
        studentId: '210401050',
        studentName: 'Tanvir Rahman',
        doctorUid: 'doc_active',
        doctorName: 'Dr. Md Nakib Hayat',
        doctorDesignation: 'Medical Officer',
        diagnosis: 'Seasonal Influenza',
        items: [
          {
            name: 'Napa 500mg',
            dose: '1 tablet',
            frequency: '1+0+1',
            duration: '3 days',
          },
        ],
        source: 'digital',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext('student_owner', {
      email: 'owner@baust.edu.bd',
      email_verified: true,
    }).firestore();

    const otherStudentDb = testEnv.authenticatedContext('student_other', {
      email: 'other@baust.edu.bd',
      email_verified: true,
    }).firestore();

    const doctorDb = testEnv.authenticatedContext('doc_active', {
      email: 'doc@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // 1. Student reads own prescription -> ALLOWED
    await assertSucceeds(ownerDb.collection('prescriptions').doc('rx_test').get());

    // 2. Student cannot read another student's prescription -> DENIED
    await assertFails(otherStudentDb.collection('prescriptions').doc('rx_test').get());

    // 3. Doctor can read prescription -> ALLOWED
    await assertSucceeds(doctorDb.collection('prescriptions').doc('rx_test').get());

    // 4. Update denied for everyone (doctor & student) -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_test').update({
      diagnosis: 'Modified Diagnosis',
    }));
    await assertFails(ownerDb.collection('prescriptions').doc('rx_test').update({
      diagnosis: 'Hacked Diagnosis',
    }));

    // 5. Delete denied for everyone -> DENIED
    await assertFails(doctorDb.collection('prescriptions').doc('rx_test').delete());
    await assertFails(ownerDb.collection('prescriptions').doc('rx_test').delete());
  });

  // 25. access_logs accepts 'create_prescription' only from approved doctor
  it('25. access_logs accepts "create_prescription" only from approved doctor', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc('doctor_active').set({
        uid: 'doctor_active',
        role: 'doctor',
        email: 'doc@baust.edu.bd',
        approved: true,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
      await db.collection('users').doc('student_1').set({
        uid: 'student_1',
        role: 'student',
        email: 'student@baust.edu.bd',
        approved: false,
        verificationStatus: 'verified',
        bloodGroupVerified: false,
      });
    });

    const doctorDb = testEnv.authenticatedContext('doctor_active', {
      email: 'doc@baust.edu.bd',
      email_verified: true,
    }).firestore();

    const studentDb = testEnv.authenticatedContext('student_1', {
      email: 'student@baust.edu.bd',
      email_verified: true,
    }).firestore();

    // Doctor logs 'create_prescription' -> SUCCEEDS
    await assertSucceeds(doctorDb.collection('access_logs').doc('log_rx_1').set({
      doctorUid: 'doctor_active',
      doctorName: 'Dr. Md Nakib Hayat',
      studentUid: 'student_1',
      studentId: '210401050',
      action: 'create_prescription',
      createdAt: new Date(),
    }));

    // Student logs 'create_prescription' -> DENIED
    await assertFails(studentDb.collection('access_logs').doc('log_rx_student').set({
      doctorUid: 'student_1',
      doctorName: 'Imposter',
      studentUid: 'student_1',
      studentId: '210401050',
      action: 'create_prescription',
      createdAt: new Date(),
    }));
  });
});
