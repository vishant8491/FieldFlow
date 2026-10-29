# FieldFlow Manual QA Test Execution Guide

This manual testing guide provides a comprehensive, end-to-end verification plan for the **FieldFlow** offline-first Flutter application on physical Android devices and emulators.

---

## 1. Prerequisites & Environment Setup

- **Target OS**: Android 10+ (API Level 29+ recommended)
- **App Configuration**: Standalone offline application (no cloud sync, no Firebase, no login credentials required).
- **Permissions Required**:
  - `CAMERA`: For taking site inspection photos.
  - `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`: For picking photos from device gallery.
  - `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`: For capturing job site GPS coordinates.
- **Test Database Isolation**: To start fresh at any point, go to **Settings -> Clear All App Data & Reset**.

---

## 2. Synthetic Test Data Reference

Use the following synthetic records for consistency during manual test runs:

| Field | Primary Record | Secondary Record |
| :--- | :--- | :--- |
| **Customer Name** | Apex Industrial Solutions | Beacon Logistics Hub |
| **Phone** | (555) 234-5678 | (555) 876-5432 |
| **Email** | dispatch@apexindustrial.example.com | operations@beaconlogistics.example.com |
| **Job Title** | Emergency Generator 500hr Overhaul | Rooftop HVAC Air Handler Inspection |
| **Address** | 4500 Industrial Parkway, Dock 4, Seattle, WA | 1200 Commercial Way, Suite 300, Portland, OR |
| **GPS Coordinates**| `47.530100`, `-122.325600` (Accuracy: 4.2m) | `45.515200`, `-122.678400` (Accuracy: 5.0m) |
| **Signer Name** | David Vance, Facilities Lead | Sarah Jenkins, Site Supervisor |

---

## 3. Step-by-Step Verification Scenarios

### Scenario 1: First-Time Launch & Empty Workspace Mode
1. **Action**: Clear app storage in Android App Info or perform a fresh install. Launch the application.
2. **Expected Result**: The Onboarding screen appears with welcome slides describing offline job management, checklists, photos, and signatures.
3. **Action**: Tap **"Start with Empty Workspace"**.
4. **Expected Result**:
   - The app navigates to the Dashboard.
   - All metric counters (Today, Upcoming, Overdue, Completed) display `0`.
   - The recent jobs section displays an empty state banner with a prompt to create a first job.
   - Re-launching the app does not show the onboarding screen again.

---

### Scenario 2: Load Demo Workspace & Synthetic Data Validation
1. **Action**: Navigate to **Settings** tab (gear icon) -> tap **"Load Demo Data"** (or select "Load Demo Workspace" during initial onboarding).
2. **Expected Result**:
   - Success notification appears.
   - The Dashboard updates immediately with pre-populated synthetic jobs across various statuses:
     - At least 1 Draft job (incomplete, missing customer/schedule).
     - At least 1 Scheduled job for Today.
     - At least 1 In Progress job.
     - At least 1 Completed job with existing sign-off.
     - At least 1 Cancelled job with documented reason.
   - All demo customer names, phone numbers (555-prefix), and email domains (`@example.com`) are synthetic.
   - Relaunching the application does **not** duplicate the demo records.
   - Deleting a demo job persists across app restarts (demo data is not silently reloaded).

---

### Scenario 3: Customer Management (Create, Edit, Delete Guard)
1. **Action**: Navigate to **Jobs** tab -> tap the floating action button (FAB) -> or open customer selector.
2. **Action**: Tap **"Add New Customer"**.
3. **Action**: Submit the form with spaces or empty strings.
4. **Expected Result**: Inline validation errors appear: `"Customer name is required"` and `"Phone number is required"`.
5. **Action**: Enter invalid email format (e.g. `invalid-email`).
6. **Expected Result**: Inline error appears: `"Enter a valid email address"`.
7. **Action**: Enter valid synthetic data:
   - Name: `Apex Industrial Solutions`
   - Phone: `(555) 234-5678`
   - Email: `dispatch@apexindustrial.example.com`
   - Tap **"Save Customer"**.
8. **Expected Result**: Customer is saved, appears in the customer picker list, and is immediately selectable.
9. **Action**: Create a job referencing `Apex Industrial Solutions`.
10. **Action**: Navigate to Customer Management and attempt to delete `Apex Industrial Solutions`.
11. **Expected Result**: System rejects deletion with an alert dialog: `"Cannot delete customer: 1 active job(s) are associated with this customer"`.

---

### Scenario 4: Job Creation & Form Validation
1. **Action**: Tap **"+"** on Dashboard or Jobs screen to open the Job Form.
2. **Action**: Enter only the Title: `Incomplete Site Survey` and tap **"Save as Draft (Incomplete)"**.
3. **Expected Result**:
   - Job is saved successfully with status **Draft**.
   - No validation errors for customer, address, or schedule.
   - App returns to list; new job displays a grey `Draft` badge.
4. **Action**: Tap **"+"** again to create a new job.
5. **Action**: Tap **"Save & Schedule Job"** without filling fields.
6. **Expected Result**: Inline errors appear under Title, Customer, Address, and Scheduled Date.
7. **Action**: Enter valid Title, select Customer, enter Address, choose date/time.
8. **Action**: Enter invalid latitude `95.0` or nonfinite string `NaN`.
9. **Expected Result**: Validation error appears: `"Latitude must be between -90 and 90"`.
10. **Action**: Fix coordinates (`47.530100`, `-122.325600`) and tap **"Save & Schedule Job"**.
11. **Expected Result**:
   - Save button shows loading spinner and disables duplicate taps.
   - Job is saved with status **Scheduled**.
   - Scheduled date and address appear formatted in the job list.

---

### Scenario 5: Job Execution & Template Application
1. **Action**: Tap on the scheduled job to open the **Job Detail Screen**.
2. **Action**: Tap the status transition button **"Start Job"**.
3. **Expected Result**:
   - Status transitions to **In Progress** with an orange badge.
   - An audit status history event is logged in the job timeline (`Scheduled -> In Progress`).
4. **Action**: In the Checklists section, tap **"Apply Template"**.
5. **Action**: Choose **"HVAC Standard Inspection"** from the bottom sheet.
6. **Expected Result**:
   - Pre-configured checklist items are imported into the job in predefined sort order.
   - Items show requirement indicators (`Required` badge).
   - All items default to `Pending` result.

---

### Scenario 6: Checklist Inspection Rules
1. **Action**: Tap **"Pass"** on item 1 ("Check refrigerant levels").
2. **Expected Result**: Item turns green with a checkmark badge; result is saved as `Pass`.
3. **Action**: Tap **"Fail"** on item 2 ("Inspect blower motor belt").
4. **Expected Result**: A dialog prompts: `"Comment Required: Explain reason for failure"`.
5. **Action**: Attempt to tap "Save" with an empty comment field.
6. **Expected Result**: Dialog prevents saving with validation error `"Please provide a comment for failed items"`.
7. **Action**: Enter `"Belt shows significant hairline cracking and requires replacement"` and confirm.
8. **Expected Result**: Item turns red with a fail badge; entered comment appears below item.
9. **Action**: On a required item, tap **"N/A"** (Not Applicable).
10. **Expected Result**: A dialog prompts: `"Reason Required: Explain why this required item does not apply"`.
11. **Action**: Enter `"Unit does not contain auxiliary heat strip"` and save.
12. **Expected Result**: Item turns grey with N/A badge; reason text is displayed.

---

### Scenario 7: Checklist Item Reordering
1. **Action**: Long press the drag handle icon on any checklist item.
2. **Action**: Drag the item up or down to a new position in the list and release.
3. **Expected Result**:
   - List visually animates to new order.
   - New sort order is persisted immediately to SQLite.
   - Exiting the screen and reopening the job preserves the updated item order.

---

### Scenario 8: Photo Evidence Capture & Attachment Safety
1. **Action**: In Job Detail Screen, tap **"Add Photo"**.
2. **Action**: Select **"Take Photo"** (or "Choose from Gallery").
3. **Action**: Grant runtime permission if prompted; take or pick a photo.
4. **Action**: Enter a caption: `"Worn drive belt condition"` and confirm.
5. **Expected Result**:
   - Photo is copied to durable app storage (`attachments/job_<id>_<uuid>.jpg`).
   - Image thumbnail renders with caption and capture timestamp.
   - Tap thumbnail to view full-screen image viewer.
6. **Action**: Tap the delete icon on the photo; confirm dialog.
7. **Expected Result**: Photo is removed from screen and database, and physical file is safely deleted from internal storage.

---

### Scenario 9: Customer Sign-off Canvas & Storage
1. **Action**: Tap **"Capture Sign-off"**.
2. **Expected Result**: Full-screen signature canvas dialog opens.
3. **Action**: Leave canvas blank and tap **"Confirm Sign-off"**.
4. **Expected Result**: Error alert appears: `"Please provide a signature before confirming"`.
5. **Action**: Draw a signature on the canvas without entering a signer name.
6. **Expected Result**: Error alert appears: `"Signer name is required"`.
7. **Action**: Tap **"Clear Canvas"**.
8. **Expected Result**: Canvas clears completely; stroke count resets to 0.
9. **Action**: Enter Signer Name: `David Vance, Facilities Lead`, draw a signature, and tap **"Confirm Sign-off"**.
10. **Expected Result**:
   - Signature is rasterized to PNG and saved to durable internal storage (`signatures/sig_<id>_<timestamp>.png`).
   - Sign-off preview renders on the job detail screen with signer name and timestamp.

---

### Scenario 10: Completion Blockers Verification
1. **Action**: Ensure at least one required checklist item is still `Pending`.
2. **Action**: Tap **"Complete Job"**.
3. **Expected Result**:
   - The app blocks completion and displays the **Completion Blockers** summary modal.
   - Modal lists all unsatisfied requirements simultaneously:
     - Unfinished required checklist items.
     - Any failed item missing a comment.
     - Any required N/A item missing a reason.
     - Missing customer sign-off (if not signed).
4. **Action**: Resolve all listed blockers by updating pending checklist items.
5. **Action**: Tap **"Complete Job"** again.
6. **Expected Result**: Confirmation dialog appears: `"Are you sure you want to mark this job as Completed? The record will become read-only."`

---

### Scenario 11: Job Completion & Read-Only Enforcement
1. **Action**: Confirm completion in dialog.
2. **Expected Result**:
   - Status updates to **Completed** with a green badge.
   - `completedAt` timestamp is recorded.
   - Status transition event is saved to history timeline.
3. **Action**: Inspect the Job Detail Screen UI.
4. **Expected Result**:
   - Edit Job button is disabled or hidden.
   - Checklist result buttons (Pass, Fail, N/A) are disabled.
   - Reorder handles on checklist items are hidden.
   - "Add Photo" and "Add Note" buttons are disabled/hidden.
   - "Capture Sign-off" button is replaced with view-only sign-off card.

---

### Scenario 12: PDF Service Report Generation & Actions
1. **Action**: On the completed job screen, tap **"View PDF Report"**.
2. **Expected Result**:
   - PDF Preview Screen opens rendering a professional multi-page document.
   - Document contains:
     - Branded header ("FieldFlow Service Report").
     - Job metadata: Title, Job ID, Status, Scheduled Date, Completed Date.
     - Customer details: Name, Address, Phone, Email.
     - GPS Location coordinates and capture timestamp (if captured).
     - Formatted checklist table with results, comments, and reasons.
     - Photo evidence section with high-resolution images and captions.
     - Customer Sign-off section with signature image, signer name, and date.
3. **Action**: Tap the **Share** icon in the preview header.
4. **Expected Result**: System share sheet opens with the generated PDF attached.
5. **Action**: Tap the **Print** icon.
6. **Expected Result**: Android Print Spooler dialog opens with print layout.

---

### Scenario 13: Job Reopening Lifecycle & Audit Trail
1. **Action**: On the completed job, tap the overflow menu or bottom action: **"Reopen Job"**.
2. **Expected Result**: Dialog prompts: `"Reason for Reopening (Required)"`.
3. **Action**: Enter `"Customer requested additional inspection of backup circuit breakers"` and confirm.
4. **Expected Result**:
   - Status transitions from `Completed` back to `In Progress`.
   - Previous status history and sign-off records are preserved.
   - Previous sign-off is marked as `isCurrent = false` (a notice indicates prior sign-off is voided).
   - Checklist items and photo attachments become editable again.
5. **Action**: Attempt to immediately tap **"Complete Job"**.
6. **Expected Result**: Completion is blocked because re-completion requires a fresh, current customer sign-off.
7. **Action**: Capture a new sign-off, then tap **"Complete Job"**.
8. **Expected Result**: Job completes again; timeline displays full audit trail including initial completion, reopening, and final recompletion.

---

### Scenario 14: Settings, Database Reset & Storage Cleanup
1. **Action**: Navigate to **Settings** screen.
2. **Action**: Toggle **Dark Mode / Light Mode**.
3. **Expected Result**: App theme instantly switches and persists across restarts.
4. **Action**: Observe **Storage Used** metric (shows KB/MB of photos and signatures).
5. **Action**: Tap **"Clear All App Data & Reset"** and confirm warning.
6. **Expected Result**:
   - All SQLite database tables are wiped.
   - All physical images in attachments and signatures directories are deleted from disk.
   - App returns to Onboarding screen as a clean installation.

---

## 4. Physical Device Hardware-Specific Validations

Perform these checks specifically on a physical Android handset:

| Hardware Feature | Action | Expected Behavior |
| :--- | :--- | :--- |
| **Camera Hardware** | Tap "Take Photo" in Job Detail screen | Native Android Camera app opens; captures photo, returns to app without crash; thumbnail loads. |
| **Gallery Picker** | Tap "Choose from Gallery" | Android Photo Picker opens; selects JPEG/PNG image; copies into app storage. |
| **GPS / Location** | Tap "Capture GPS Location" in Job Form | Prompts for location permission ("While using the app"); acquires current latitude, longitude, and accuracy in meters. |
| **Native Share Sheet** | Tap Share icon in PDF Preview | Android OS Sharesheet opens showing Gmail, WhatsApp, Drive, Bluetooth, etc. |
| **Print Spooler** | Tap Print icon in PDF Preview | Android Print Preview displays pages; allows saving as PDF or printing to Wi-Fi printer. |
| **Screen Rotation** | Rotate phone between Portrait and Landscape | Forms, checklist items, and signature dialog adapt without layout overflow or resetting entered text. |
| **Keyboard Insets** | Tap notes or comments text field | Keyboard slides up; scroll view adjusts automatically so text input remains visible. |
| **Offline Mode (Airplane)** | Enable Airplane mode and complete an entire job journey | App performs all database writes, image saves, and PDF generation with 0 network calls and 0 errors. |

---

## 5. Safe Cleanup After Testing

To reset the device to its pristine baseline state after completing QA:
1. Open FieldFlow -> Settings -> **"Clear All App Data & Reset"**.
2. Alternatively, go to Android Settings -> Apps -> FieldFlow -> Storage -> **"Clear Storage"**.

