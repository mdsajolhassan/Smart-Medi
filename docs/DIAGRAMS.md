# Smart Medi - System Design Diagrams

### 1. Use Case Diagram
```mermaid
graph TD
    student((Student)) --> (Login to Portal)
    student --> (Trigger Emergency SOS)
    student --> (Upload Medical History)
    
    doctor((Doctor)) --> (Login to Portal)
    doctor --> (Lookup Patient History)
    doctor --> (Issue Digital Prescription)
    doctor --> (Scan Paper Prescription)

    pharmacist((Pharmacist)) --> (Login to Portal)
    pharmacist --> (Dispense Medicine)
    pharmacist --> (Manage Inventory Stock)

    admin((Super Admin)) --> (Approve Pending Users)
    admin --> (Monitor System Logs)

    ai((Gemini AI))
    (Scan Paper Prescription) --> ai
    ai --> (Scan Paper Prescription)

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

    
