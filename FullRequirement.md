# KIDPRO - Comprehensive Software Requirement Specification (SRS)
**Project:** Smart Preschool Management, Child Safety, and Dynamic Tuition Platform

## 1. System Architecture & External Integrations
KIDPRO operates on a multi-tenant architecture with the following core integrations:
*   **AI Facial Recognition Microservice:** Python (FastAPI) utilizing YOLOv8-Face (Detection) and InsightFace (Extraction of 512-dim feature vectors). Matches vectors using PostgreSQL with `pgvector` (HNSW indexing) via Cosine Similarity.
*   **Payment Gateway:** VietQR / SePAY / PayOS for generating dynamic QR codes with fixed amounts and reference notes. Supports 3-second server-to-server IPN/Webhook reconciliation.
*   **Cloud Storage:** AWS S3 / MinIO for secure storage of student biometric photos, medication prescriptions, and daily activity logs (Presigned URLs used for access).
*   **Push Notifications:** Firebase Cloud Messaging (FCM) for real-time mobile push alerts attached with snapshot photos.
*   **Email Service:** Gmail SMTP for dispatching official verification notices and OTPs.

---

## 2. Actors Definition
1.  **Platform Super Admin:** Manages tenant onboarding, global AI/VietQR configs, monitors system health (API latency, AWS costs).
2.  **Principal (BGH):** Approves classroom structures, tuition fee policies, and views executive operational dashboards.
3.  **Academic Affairs (Giáo vụ):** Manages admissions, timetables, handles class transfers, and legally verifies authorized pickup guardian profiles (ID cards/photos).
4.  **Accountant (Kế toán):** Configures fee categories, runs month-end dynamic tuition jobs, and handles manual/auto debt reconciliation.
5.  **Teacher (Giáo viên):** Uses mobile/tablet app for AI check-in/out, logs medication, updates visual journals, and evaluates students (5 Domains - MOET Circular 51).
6.  **Kitchen Staff (Nhân viên Bếp):** Monitors the 08:30 AM locked meal dashboard, prepares specific dietary meals (porridge, allergen-free).
7.  **Parent (Phụ huynh):** Submits digital absence (before 08:00 AM), registers biometric faces, views photo timelines, and pays tuition via 1-tap VietQR.

---

## 3. Core Automated Workflows & Background Services
### 3.1. Background Workers (Non-UI Functions)
*   **08:30 AM Meal Lock Cron Job:** Executes exactly at 08:30 AM daily. Scans attendance records -> calculates exact meal portions needed (Regular, Porridge, Allergen-free) -> Locks the dataset -> Pushes to Kitchen Dashboard.
*   **VietQR Webhook Listener:** Secure endpoint (`/vnpay-ipn` or similar). Validates HMAC-SHA512 signature -> Maps transaction note -> Updates Invoice status to `PAID` -> Generates Electronic Receipt -> Pushes FCM to Parent (Latency < 3s).
*   **Dynamic Tuition Calculation Engine:** Month-end batch job. Formula: `(Base Fixed Fees) + (Extra Services) - (Excused Absences * Daily Meal Rate) + (Late Pickup Minutes * Penalty Rate)`.
*   **JWT Session Manager:** Uses Redis. Access Token (15 min), Refresh Token (7 days/30 days for Remember Me). Subscribes to Redis `force_logout` channel to instantly revoke sessions if a user is banned or changes password.
*   **AWS S3 Async Retry Worker:** Background queue that retries uploading check-in/out snapshot photos if the tablet loses local network connection during rush hour.

---

## 4. Feature Requirements (Categorized Use Cases)

### Module 1: School Management & Academic Affairs
*   **Tenant Onboarding:** Super Admin can create new school instances, provision Principal accounts.
*   **Classroom & Timetable Setup:** Drag-and-drop weekly timetable scheduling. System auto-detects schedule/room conflicts (e.g., Music room double-booked).
*   **Guardian Verification:** Parents upload Guardian ID & Portrait. Academic Affairs *must* manually verify documents before system extracts the 512-dim AI vector.
*   **Student Health Profile:** Track height, weight, BMI (WHO standards). System-wide warning banners for severe food allergies (peanuts, seafood) visible to Kitchen and Teachers.

### Module 2: AI Face Attendance & Classroom Operations (Teacher App)
*   **Morning AI Check-in:** Teacher points tablet at incoming child. AI detects face -> returns identity < 0.3s -> Captures snapshot -> Marks `PRESENT` -> Pushes FCM to Parent.
*   **Fallback Attendance:** 1-tap manual check-in or QR Code scan (used in bad lighting or if child wears mask).
*   **Afternoon AI Dismissal:** Teacher scans Guardian's face at the gate. System verifies against authorized list (Primary/Secondary guardians).
*   **Stranger Alert:** If face is unregistered, system flashes red, rings chime. Teacher holds child, triggers Emergency Pickup Approval workflow.
*   **Late Pickup Tracker:** System auto-stamps pickups after 17:30 to forward penalty data to Accounting.
*   **Medication Handover:** Teacher signs digital handover in morning, takes photo proof when administering medication at 14:00.

### Module 3: Tuition & Dynamic Billing (Accountant)
*   **Fee Categories:** Configure monthly fixed, daily attendance multiplication, or annual one-time fees.
*   **Meal Refund Auto-Credit:** Parent submits absence *before 08:00 AM* -> System approves -> Multiplies absent days by Daily Meal Rate -> Deducts from next month's invoice.
*   **Bulk Invoicing:** Accountant reviews system-generated statements, approves in bulk -> Triggers FCM with PayOS VietQR links to parents.
*   **Manual Reconciliation:** Accountant logs physical cash payments or bank transfers with missing/wrong reference codes.

### Module 4: Parent Application Experience
*   **Biometric Registration:** Upload 3 straight-angle photos of child/guardians for AI processing.
*   **Emergency Pickup Authorization:** Temporary 1-day authorization (e.g., Uncle picks up) requires uploading ID photo and phone number.
*   **Digital Absence & Medicine:** Submit leave requests (cut-off 08:00 AM). Upload doctor's prescription and dosage instructions.
*   **One-Way Timeline:** View photo feed, meal consumption levels (Finished/Half/Skipped), nap times, and daily evaluations.
*   **Tuition Settlement:** Transparent statement view (showing exact deductions). 1-tap redirect to banking app via PayOS deep link.
*   **Data Deletion Right (Decree 13):** Parents can request permanent deletion of biometric vectors upon graduation/transfer.

---

## 5. Screen Authorization Matrix (RBAC)
*Legend: [SA]=Super Admin, [PR]=Principal, [AA]=Academic Affairs, [AC]=Accountant, [TE]=Teacher, [KI]=Kitchen, [PA]=Parent*

### Web Admin Routing
| Screen/Route | Permitted Roles |
| :--- | :--- |
| **System Admin Dashboard, Tenant Mgmt, Audit Logs** | `[SA]` |
| **Academic Affairs Portal, Student Profile, Enrollment** | `[PR]`, `[AA]` |
| **Classroom Mgmt, Roster, Attendance Reports** | `[PR]`, `[AA]`, `[AC]`, `[TE]`, `[KI]` |
| **Create Classroom, Teacher Assignment** | `[PR]`, `[AA]` |
| **Timetable & Menu Setup** | `[PR]`, `[AA]`, `[TE]` (Menu also `[KI]`) |
| **Tuition Policy, Payment Orders, Debt Reconciliation** | `[PR]`, `[AC]` |
| **Pickup Safety & ID Verification Approval** | `[PR]`, `[AA]`, `[TE]` |

### Mobile App Routing
| Screen/Route | Permitted Roles |
| :--- | :--- |
| **Teacher Dashboard, AI Check-in/out, Fallback QR** | `[TE]` |
| **Medication Mgmt, Visual Journal, Evaluate 5 Domains**| `[TE]` |
| **Leave Approval, Resolve Absence Discrepancy** | `[TE]`, `[AA]` |
| **Parent Dashboard, Face Registration, 1-Tap VietQR** | `[PA]` |
| **Digital Absence, E-Receipts, Tuition Dispute** | `[PA]` |
| **Timetable, Menu Detail, One-Way Photo Feed** | `[PA]` |

---

## 6. Detail Use Case Specification Example (UC-001: Login)
**Preconditions:** User has active account. Network is connected.
**Main Flow:**
1. User inputs Phone/Email + Password on Web/Mobile. (Optional "Remember Me").
2. API validates payload format. Queries DB via identifier.
3. System verifies password using BCrypt.
4. Checks status: Must be `ACTIVE`.
5. Generates JWT Tokens. Access (15m), Refresh (7d, or 30d if Remember Me). Caches session in Redis.
6. Returns tokens and Role ID. Frontend redirects to respective Role Dashboard.

**Exceptions:**
*   *Invalid Creds:* Increments Redis failed counter. Returns `MSG-001: "Incorrect credentials. {n} attempts left."`
*   *Lockout Policy:* If 5 consecutive fails within 15 mins -> Lock account in Redis for 15 mins. Returns `MSG-003`.
*   *Suspended:* Returns `MSG-002: "Account inactive."`

---

## 7. Non-Functional Requirements (SLAs)
*   **Performance (AI):** Face bounding box detection + Vector extraction (YOLOv8 + InsightFace) must be `< 50ms`. Vector DB matching (PGvector) must be `< 0.3s`.
*   **Performance (Web):** Backend API response time for CRUD operations `< 300ms`.
*   **Reliability:** 99.5% uptime. Mobile app must have offline-caching for manual attendance if WiFi drops, auto-syncing when restored.
*   **Security:** Passwords hashed with BCrypt (Cost factor 10+). Presigned S3 URLs expire in 15 minutes. Biometric data strictly governed by Vietnam Decree 13/2023/ND-CP (Right to deletion).
*   **Rate Limiting:** Public endpoints (Login, OTP) limited to 60 req/min per IP to prevent DDoS.