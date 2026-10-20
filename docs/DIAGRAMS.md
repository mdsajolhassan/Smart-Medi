graph TD
    student["Student"] --> login1["Login to Portal"]
    student --> sos["Trigger Emergency SOS"]
    student --> medHistory["Upload Medical History"]
    
    doctor["Doctor"] --> login2["Login to Portal"]
    doctor --> lookup["Lookup Patient History"]
    doctor --> rx["Issue Digital Prescription"]
    doctor --> scan["Scan Paper Prescription"]

    pharmacist["Pharmacist"] --> login3["Login to Portal"]
    pharmacist --> dispense["Dispense Medicine"]
    pharmacist --> inventory["Manage Inventory Stock"]

    admin["Super Admin"] --> approve["Approve Pending Users"]
    admin --> logs["Monitor System Logs"]

    ai["Gemini AI"]
    scan --> ai
    ai --> scan

stateDiagram-v2
    [*] --> Upload_Prescription_Image
    Upload_Prescription_Image --> Call_Gemini_API
    
    Call_Gemini_API --> Check_Rate_Limit
    Check_Rate_Limit --> Rotate_API_Key : HTTP 429 / 403 Error
    Rotate_API_Key --> Call_Gemini_API : Retry with new key
    
    Check_Rate_Limit --> Extract_Data : Success (HTTP 200)
    Extract_Data --> Auto_Fill_UI_Form
    Auto_Fill_UI_Form --> Doctor_Reviews_Data
    Doctor_Reviews_Data --> Submit_to_Firestore
    Submit_to_Firestore --> [*]

sequenceDiagram
    participant Doc as Doctor
    participant App as Smart Medi App
    participant AI as Gemini API
    participant DB as Firebase Firestore

    Doc->>App: Clicks "Scan Prescription"
    App->>App: Picks Image from Gallery/Camera
    App->>AI: Send Image + Prompt (Using Key 1)
    
    alt API Limit Exceeded
        AI-->>App: Error (429 Too Many Requests)
        App->>AI: Switch to Key 2 & Retry
    end
    
    AI-->>App: Extracted JSON Data (Medicines & Diagnosis)
    App->>App: Auto-fill Form Fields
    Doc->>App: Verifies & Modifies Data
    Doc->>App: Clicks "Submit"
    App->>DB: Save Prescription Document
    DB-->>App: Success Confirmation
    App-->>Doc: Show Success Snackbar

classDiagram
    class UserProfile {
        +String uid
        +String name
        +String role
        +String email
        +bool isApproved
    }
    class StudentProfile {
        +String studentId
        +String department
        +String bloodGroup
        +triggerSOS()
    }
    class DoctorProfile {
        +String specialization
        +issuePrescription()
    }
    class InventoryItem {
        +String id
        +String name
        +int currentStock
        +updateStock(multiplier)
    }
    class Prescription {
        +String id
        +String studentUid
        +List medicines
        +String diagnosis
    }
    
    UserProfile <|-- StudentProfile
    UserProfile <|-- DoctorProfile
    DoctorProfile --> Prescription : Creates
    Pharmacist --> InventoryItem : Manages
    StudentProfile "1" -- "*" Prescription : Receives
