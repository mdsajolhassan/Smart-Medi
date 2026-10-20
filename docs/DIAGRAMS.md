# Smart Medi – UML Diagrams

## 1. Use Case Diagram

```mermaid
flowchart LR
    student(["Student"])
    doctor(["Doctor"])
    pharmacist(["Pharmacist / Nurse"])
    admin(["Super Admin"])
    ai(["Gemini AI (external)"])

    subgraph SYS["Smart Medi System"]
        uc1["Login & Role Verification"]
        uc2["Upload Medical History"]
        uc3["View Own Medical History & Prescriptions"]
        uc4["Trigger Emergency SOS"]
        uc5["Search Blood Donors"]
        uc6["Lookup Patient by Student ID"]
        uc7["Issue Digital Prescription"]
        uc8["Scan Paper Prescription"]
        uc9["Manage Inventory Stock"]
        uc10["Approve Pending Staff Accounts"]
        uc11["View Access Logs"]
    end

    student --- uc1
    student --- uc2
    student --- uc3
    student --- uc4
    student --- uc5
    doctor --- uc1
    doctor --- uc6
    doctor --- uc7
    doctor --- uc8
    pharmacist --- uc1
    pharmacist --- uc9
    admin --- uc10
    admin --- uc11
    uc2 --- ai
    uc8 --- ai
```

## 2. Activity Diagram – Scan Paper Prescription

```mermaid
flowchart TD
    A([Start]) --> B[Doctor opens New Prescription]
    B --> C[Select Scan Paper Prescription]
    C --> D[Pick image from camera or gallery]
    D --> E[Send image to Gemini AI]
    E --> F{Request successful?}
    F -- "429 / 503 / timeout" --> G[Retry or rotate key / fallback model]
    G --> E
    F -- "All keys and models failed" --> H[Show friendly message, fill form manually]
    F -- "200 OK" --> I[Extract medicines and diagnosis]
    I --> J{Patient name matches?}
    J -- No --> K[Show name-mismatch warning]
    J -- Yes --> L[Auto-fill form fields]
    K --> L
    H --> M[Doctor reviews and edits data]
    L --> M
    M --> N{Allergy conflict?}
    N -- Yes --> O[Show allergy warning, doctor confirms]
    N -- No --> P[Confirm and submit]
    O --> P
    P --> Q[Save prescription to Firestore]
    Q --> R([End])
```

## 3. Activity Diagram – Student Medical History Upload

```mermaid
flowchart TD
    A([Start]) --> B[Student logs in]
    B --> C[Upload medical document]
    C --> D[Gemini AI extracts history]
    D --> E{Extraction OK?}
    E -- No --> F[Fill form manually]
    E -- Yes --> G[Mark fields as AI-extracted, unverified]
    F --> H[Student reviews and confirms]
    G --> H
    H --> I[Save medical history to Firestore]
    I --> J([End])
```

## 4. Sequence Diagram – Scan Prescription with Key and Model Fallback

```mermaid
sequenceDiagram
    participant Doc as Doctor
    participant App as Smart Medi App
    participant AI as Gemini API
    participant DB as Firebase Firestore

    Doc->>App: Click "Scan Paper Prescription"
    App->>App: Pick image from gallery or camera
    App->>AI: Send image + prompt (model 1, key 1)

    alt 503 / timeout
        AI-->>App: Error
        App->>AI: Retry same key (2s, then 5s)
    else 429 quota
        AI-->>App: Error 429
        App->>AI: Rotate to next key
    else 403 dead key
        AI-->>App: Error 403
        App->>App: Mark key dead, use next key
    else 404 model unavailable
        AI-->>App: Error 404
        App->>AI: Use next model in chain
    end

    AI-->>App: Extracted JSON (medicines, diagnosis)
    App->>App: Name-mismatch check, auto-fill form
    Doc->>App: Review and edit data
    App->>App: Allergy check against patient history
    App-->>Doc: Show allergy warning if conflict
    Doc->>App: Confirm and submit
    App->>DB: Save prescription + access log
    DB-->>App: Success
    App-->>Doc: Show success message
```

## 5. Class Diagram

```mermaid
classDiagram
    class UserProfile {
        +String uid
        +String name
        +String email
        +String role
        +bool approved
        +String verificationStatus
        +String bmdcRegistrationNumber
    }
    class Student {
        +String studentId
        +String department
        +String bloodGroup
        +triggerSOS()
        +uploadMedicalHistory()
    }
    class Doctor {
        +String designation
        +lookupPatient()
        +issuePrescription()
        +scanPrescription()
    }
    class Pharmacist {
        +manageInventory()
    }
    class SuperAdmin {
        +approveStaff()
        +viewAccessLogs()
    }
    class MedicalHistory {
        +String studentUid
        +List allergies
        +List conditions
        +bool aiExtracted
    }
    class Prescription {
        +String id
        +String studentUid
        +String studentId
        +String doctorUid
        +String diagnosis
        +String advice
        +String followUpDate
        +String source
        +DateTime createdAt
    }
    class PrescriptionItem {
        +String drugName
        +String dose
        +String frequency
        +String duration
    }
    class InventoryItem {
        +String id
        +String name
        +int currentStock
        +updateStock(delta)
    }
    class EmergencyAlert {
        +String studentUid
        +String hall
        +String room
        +String status
    }
    class AccessLog {
        +String doctorUid
        +String studentUid
        +String action
        +DateTime timestamp
    }

    UserProfile <|-- Student
    UserProfile <|-- Doctor
    UserProfile <|-- Pharmacist
    UserProfile <|-- SuperAdmin
    Student "1" --> "1" MedicalHistory : has
    Student "1" --> "*" Prescription : receives
    Student "1" --> "*" EmergencyAlert : triggers
    Doctor "1" --> "*" Prescription : issues
    Doctor "1" --> "*" AccessLog : generates
    Prescription "1" *-- "1..20" PrescriptionItem : contains
    Pharmacist "1" --> "*" InventoryItem : manages
```
