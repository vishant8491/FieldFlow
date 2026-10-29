# FieldFlow — Physical Device Testing Checklist

This manual verification checklist is designed for QA testing, field validation, and portfolio demonstrations of **FieldFlow** on physical Android hardware across different Android OS versions (Android 10 through Android 14+).

---

## 1. Environment & Setup

- [ ] **Target Device**: Physical Android handset (or Android Emulator with Google Play Services).
- [ ] **Architecture**: ARM64 / x86_64.
- [ ] **App Build**: Debug or Release APK (`build/app/outputs/flutter-apk/app-debug.apk`).
- [ ] **Initial State**: Fresh install (or clear app data before test).

---

## 2. Onboarding & Initial State

| Test ID | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- |
| **ONB-01** | Fresh install launch | Onboarding screen appears with welcome banner and explanation. | [ ] |
| **ONB-02** | Tap **"Start Empty"** | Transitions to Dashboard with 0 jobs, 0 active, clean counters, and empty state CTA. | [ ] |
| **ONB-03** | App relaunch after Onboarding | App launches directly to Dashboard; Onboarding is not shown again. | [ ] |
| **ONB-04** | Reset Data & choose **"Load Demo Workspace"** | Seeds 4 customers, 3 templates, 5 demo jobs across all statuses, notes, and a demo sign-off. | [ ] |
| **ONB-05** | Demo Data Integrity | Demo jobs contain realistic timestamps, priorities, and inspection checklist items. | [ ] |

---

## 3. Camera & Gallery Photo Evidence

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **CAM-01** | Camera Permission Granted | Open In-Progress job -> Evidence tab -> Tap "Camera". Accept permission dialog. | Native camera viewfinder opens. Taking a photo prompts for optional caption, saves image into durable app storage (`attachments/`), and shows thumbnail in grid. | [ ] |
| **CAM-02** | Camera Capture Cancelled | Tap "Camera", then tap Android back button or cancel button. | Viewfinder closes cleanly; no corrupted attachment record or empty thumbnail is created. | [ ] |
| **CAM-03** | Gallery Multi-Version Access | Tap "Gallery". Select an image from device storage. | On Android 13+ uses `READ_MEDIA_IMAGES` / photo picker; on Android 12- uses `READ_EXTERNAL_STORAGE`. Image copies to durable storage. | [ ] |
| **CAM-04** | Permission Denied | In system settings, deny camera/storage. Tap "Camera" in app. | App displays an actionable SnackBar explaining that camera permission is required; app does not crash or freeze. | [ ] |
| **CAM-05** | Permission Permanently Denied | Check "Don't ask again" and deny permission. Tap "Camera". | SnackBar offers a direct link or prompt to open Android App Settings; app gracefully stays on Evidence tab. | [ ] |
| **CAM-06** | Android Process Loss Recovery | In Android Developer Options, enable "Don't keep activities". Take photo with camera. | On return from native camera, `ImagePicker().retrieveLostData()` recovers the photo; attachment persists cleanly. | [ ] |
| **CAM-07** | Photo Fullscreen Zoom & Deletion | Tap an image thumbnail. | Full-screen interactive viewer opens with zoom/pan. Tapping delete shows confirmation dialog; on confirmation, both SQLite record and filesystem file are removed. | [ ] |

---

## 4. Location Service & Manual Overrides

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **LOC-01** | GPS Enabled & Permitted | On Job Form, tap "Capture Current Location". Grant fine location. | Retrieves device GPS coordinates (latitude, longitude, accuracy) within 10s. Fields autofill with coordinates and accuracy badge. | [ ] |
| **LOC-02** | Device Location Services Off | Turn off Android Location (GPS toggle in quick settings). Tap "Capture Current Location". | SnackBar prompts: *"Location services are disabled. Please enable GPS in device settings."* No crash. | [ ] |
| **LOC-03** | Location Permission Denied | Deny location permission when prompted. | SnackBar informs user: *"Location permission denied."* Coordinates remain editable manually. | [ ] |
| **LOC-04** | GPS Timeout Handling | In an environment with zero GPS signal (e.g., basement/faraday cage), tap capture. | 10-second timeout fires gracefully with message *"Location request timed out. Please enter manually or try again."* | [ ] |
| **LOC-05** | Manual Coordinate Validation | Manually type `95.0` for latitude or `200.0` for longitude. | Form validator highlights invalid range (`-90..90` for latitude, `-180..180` for longitude) and blocks form submission. | [ ] |
| **LOC-06** | Valid Manual Coordinates | Enter `37.7749` and `-122.4194`. Tap Save. | Coordinates persist in SQLite and display in Job Detail overview and exported PDF report. | [ ] |

---

## 5. Inspection Checklist & Completion Blocker Rules

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **CHK-01** | Apply Template | Create a job -> Open Inspection tab -> Tap "Apply Template" -> Select "Appliance Maintenance". | All items from template clone into the job checklist. Template master remains unmodified. | [ ] |
| **CHK-02** | Evaluate Item: Pass | Tap an item -> Select "Pass" -> Tap Save. | Status updates to green "Pass"; progress bar reflects completed ratio. | [ ] |
| **CHK-03** | Evaluate Item: Fail without Comment | Select "Fail", leave comment empty, tap Save. | Validation error highlights comment field: *"Comment is required when failing an item."* Save blocked. | [ ] |
| **CHK-04** | Evaluate Item: Fail with Comment | Enter reason (e.g. *"Exhaust pipe cracked"*), tap Save. | Item saves with red "Fail" chip and shows comment text. | [ ] |
| **CHK-05** | Evaluate Item: N/A on Required Item | Select "Not Applicable" on a required item without reason. | Validation error: *"A reason is required when marking a required item as N/A."* | [ ] |
| **CHK-06** | Attempt Complete with Pending Items | Tap "Complete Job" when required checklist items are still "Pending". | `CompletionBlockersDialog` modal appears listing exact blocker: *"Required checklist item '[Label]' has not been evaluated."* Job status remains `inProgress`. | [ ] |

---

## 6. Customer Sign-off Signature

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **SIG-01** | Open Signature Screen | From In-Progress job with completed checklist, tap "Sign & Complete". | Signature screen loads with signer name field, clear canvas, legal acknowledgement banner, and action buttons. | [ ] |
| **SIG-02** | Empty Signature Validation | Leave canvas blank or signer name empty, tap "Confirm Sign-Off". | Validation errors: *"Please provide the customer/signer name"* and *"Please provide a customer signature on the canvas."* | [ ] |
| **SIG-03** | Clear Canvas | Draw strokes, tap "Clear". | Canvas resets to empty without artifacts. | [ ] |
| **SIG-04** | Confirm Valid Signature | Enter "Jane Doe", draw signature, tap "Confirm Sign-Off". | Shows preview dialog. Upon confirmation, signature saves as PNG in durable app storage, creates a `sign_offs` record (`is_current = 1`), and transitions job status to `completed` in a single SQLite transaction. | [ ] |

---

## 7. Lifecycle Transitions & Immutability Rules

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **TRN-01** | Draft -> Scheduled | In Draft job, tap "Schedule Job". | Allowed only if customer and schedule date are set. Status updates to `scheduled`. | [ ] |
| **TRN-02** | Scheduled -> In Progress | Tap "Start Job". | Status updates to `inProgress`. Work timer and inspection checklist become active. | [ ] |
| **TRN-03** | Cancel with Reason | Tap "Cancel Job". Leave reason empty -> Save blocked. Enter "Customer postponed indefinitely" -> Tap Save. | Status transitions to `cancelled`; reason recorded in status history table. | [ ] |
| **TRN-04** | Completed Job Immutability | Open a `completed` job. | All fields, checklist items, attachments, and sign-offs are read-only. Edit buttons and capture controls are hidden. | [ ] |
| **TRN-05** | Explicit Job Reopening | Tap "Reopen Job". Enter reason *"Customer requested additional outlet check"*. | In one atomic transaction: status transitions to `inProgress`, history logged, and previous sign-off is marked `is_current = 0`. | [ ] |
| **TRN-06** | Re-completion Requirement | Attempt to complete reopened job without signing again. | `CompletionBlockersDialog` blocks completion: *"Valid customer sign-off signature is required."* Requires fresh signature. | [ ] |

---

## 8. PDF Generation & Android Share Sheet

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **PDF-01** | Export Draft Report | Tap "Export PDF" on a `draft` or `inProgress` job. | Multi-page PDF renders with yellow **"DRAFT REPORT — NOT SIGNED-OFF"** banner. | [ ] |
| **PDF-02** | Export Completed Report | Tap "Export PDF" on a `completed` job. | Multi-page PDF renders with green **"COMPLETED & SIGNED SERVICE REPORT"** header, customer signature image, sign-off timestamp, and signer name. | [ ] |
| **PDF-03** | Stress / Multi-Page Layout | Export a job with 25+ checklist items and multiple notes. | Table cleanly wraps across pages with running page numbers (`Page X of Y`), repeating table headers, and clean page breaks without overlapping text. | [ ] |
| **PDF-04** | Android Share Sheet | Tap share button in PDF viewer or direct share action. | Native Android share sheet appears with available targets (Gmail, Google Drive, WhatsApp, Bluetooth, Nearby Share). | [ ] |
| **PDF-05** | Missing Image Resilience | Export PDF for a job where an image file was manually deleted from disk. | PDF generator catches missing file, renders a clean fallback placeholder *"Image unavailable on device"*, and finishes rendering without crash. | [ ] |

---

## 9. App Lifecycle, Process Pause & Memory Management

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **LIF-01** | App Background / Resume | Edit job form halfway -> Press Home button -> Open other heavy apps -> Switch back to FieldFlow. | Form inputs remain intact; database connection remains active and responsive. | [ ] |
| **LIF-02** | OS Process Kill / Recreation | With app in background, run `adb shell am kill com.fieldflow.fieldflow` -> Tap app icon to resume. | App reinitializes cleanly, reads SQLite state, and displays current jobs without database corruption. | [ ] |
| **LIF-03** | Permission Revocation | While app is running, switch to Android Settings -> Revoke Camera permission -> Switch back to app. | Next camera tap requests permission again; app handles revoked state cleanly without throwing unhandled exceptions. | [ ] |

---

## 10. Settings & Storage Hygiene

| Test ID | Scenario | Procedure | Expected Result | Pass / Fail |
| :--- | :--- | :--- | :--- | :--- |
| **SET-01** | Theme Switching | Switch between System, Light, and Dark mode in Settings. | Instant Material 3 color palette switch; persists after app restart. | [ ] |
| **SET-02** | Storage Meter Calculation | Add 3 photo attachments -> Navigate to Settings -> Check Storage meter. | Accurately calculates attachment and signature directory bytes (e.g. `1.85 MB used across 3 files`). | [ ] |
| **SET-03** | Reset All Data | Tap "Reset All Data" -> Type confirmation or confirm dialog. | Wipes SQLite tables and deletes all stored images and signatures from disk; redirects cleanly to Onboarding screen. | [ ] |

