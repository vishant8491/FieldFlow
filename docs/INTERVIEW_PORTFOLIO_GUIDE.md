# FieldFlow — Interview & Portfolio Guide

This guide equips you to present **FieldFlow** in Flutter engineering interviews. It contains 15 technical questions and answers grounded directly in the codebase, a 3-minute live demonstration script, and factual resume bullet points.

---

## 🎙️ 15 Interview Questions & Answers

### 1. State Management
**Q: Why did you choose Provider with `ChangeNotifier` over Bloc, Riverpod, or GetX?**
> **A:** FieldFlow is an offline-first service application where data flows from a local SQLite database into user-facing screens. `Provider` with `ChangeNotifier` (`JobsProvider` and `ThemeProvider`) offers the ideal balance of simplicity, reactivity, and readability without boilerplate. Global state handles shared data such as loaded jobs, active filters, metrics, and theme preferences. Ephemeral UI states (like form text inputs, active tab indices, or camera preview dialogs) are managed locally using `setState`. This avoids over-engineering with complex event streams or code generation while keeping widget trees clean and testable.

### 2. Ephemeral vs Shared State Separation
**Q: How do you decide whether a state belongs in `setState` or `Provider`?**
> **A:** If state affects multiple screens, widgets, or drives navigation metrics (such as the jobs list, dashboard counters, current theme mode, or customer cache), it lives in `JobsProvider` or `ThemeProvider`. If the state is ephemeral and only relevant to a single widget’s visual lifecycle—such as text field validation errors in `JobFormScreen`, the active inspection tab index in `JobDetailScreen`, or canvas stroke points in `SignatureScreen`—it belongs strictly in `setState`. This prevents unnecessary rebuilds across the application and keeps providers focused on business logic.

### 3. Local SQLite Schema & Relational Integrity
**Q: How does FieldFlow handle relational data and prevent orphaned records in SQLite?**
> **A:** In `DatabaseService.dart`, `PRAGMA foreign_keys = ON;` is executed on every database connection. The schema defines foreign keys across tables: `jobs.customer_id REFERENCES customers(id) ON DELETE RESTRICT`, `checklist_items.job_id REFERENCES jobs(id) ON DELETE CASCADE`, `attachments.job_id REFERENCES jobs(id) ON DELETE CASCADE`, `sign_offs.job_id REFERENCES jobs(id) ON DELETE CASCADE`, and `status_history.job_id REFERENCES jobs(id) ON DELETE CASCADE`.
> For example, if a user attempts to delete a customer who has associated jobs, SQLite throws a foreign key constraint violation, which `DatabaseService.deleteCustomer()` catches and surfaces as a clean user-facing error message: *"Cannot delete customer with active or historical jobs."*

### 4. Atomic Transitions & SQLite Transactions
**Q: How do you ensure that updating a job's status and logging its history event remain consistent if an app crash occurs?**
> **A:** All status transitions run inside an atomic SQLite transaction via `DatabaseService.updateJobStatusWithTransaction()`. Inside `db.transaction((txn) async { ... })`, the method updates the `jobs` row (`status`, `updated_at`, and `completed_at` if applicable) and immediately executes an `INSERT INTO status_history` record with the previous status, next status, reason, and ISO8601 timestamp. If either statement fails, SQLite rolls back the entire transaction, guaranteeing that the database never has an updated job status without a corresponding audit history entry.

### 5. Reopening Completed Jobs
**Q: What is the business logic when a completed job is reopened? How is this enforced?**
> **A:** Once a job is completed, it becomes read-only to preserve legal integrity. If a technician needs to perform additional work, they must explicitly reopen the job and supply a mandatory reason. In `DatabaseService.reopenJobWithTransaction()`, three actions occur in a single transaction:
> 1. The job's status changes back to `inProgress`, and `completed_at` is cleared to `NULL`.
> 2. The reopening event is appended to `status_history`.
> 3. Any previous sign-off in `sign_offs` is marked `is_current = 0`.
> Because `is_current` is reset, `JobsProvider.getCompletionBlockers()` will detect that no current sign-off exists, strictly requiring the technician to capture a fresh customer signature before the job can ever be marked completed again.

### 6. Completion Blockers
**Q: How do you prevent a technician from completing an incomplete job?**
> **A:** `JobsProvider.getCompletionBlockers(jobId)` runs a comprehensive validation suite:
> 1. It verifies the job is currently `inProgress`.
> 2. It queries all required checklist items: any item still marked `pending` triggers a blocker.
> 3. Any item marked `fail` must contain an explanatory technician comment.
> 4. Any required item marked `notApplicable` must have an explanatory reason.
> 5. It queries `sign_offs` for `is_current = 1` and verifies that the signature file exists on disk and signer name is non-empty.
> If any blockers exist, `JobDetailScreen` blocks the transition and presents the `CompletionBlockersDialog`, clearly highlighting every missing requirement.

### 7. Durable File Storage vs Relative Paths
**Q: Why store relative paths in SQLite instead of absolute paths or database BLOBs?**
> **A:** Storing raw image BLOBs in SQLite causes table bloat, slow queries, and database memory spikes (`CursorWindow` overflow on Android). Conversely, storing absolute filesystem paths (like `/data/user/0/com.fieldflow...`) is fragile because the Android OS can alter the application's sandbox container directory between app updates or restores.
> FieldFlow saves files into `getApplicationDocumentsDirectory()` inside `attachments/` and `signatures/` subfolders and stores relative paths in SQLite (e.g. `attachments/job_12_photo_1.jpg`). `AttachmentService.getAbsolutePath()` dynamically prepends the current application documents path at runtime.

### 8. Camera Capture & Android Process Loss
**Q: On low-memory Android devices, launching the camera often kills the background Flutter activity. How does FieldFlow handle this?**
> **A:** When the Android OS terminates the host activity during a camera intent, the app process restarts upon returning from the camera. In `AttachmentService.dart`, we implement `ImagePicker().retrieveLostData()`. When `JobDetailScreen` initializes or when the photo picker returns, any pending image captured before process death is recovered, saved to durable storage, and added to the job's attachment records without data loss.

### 9. Single-Fix Location Capture
**Q: How does FieldFlow capture coordinates without draining device battery or requiring continuous GPS tracking?**
> **A:** FieldFlow uses `LocationService.getCurrentPosition()`, which triggers an explicit, single-fix location acquisition only when the technician taps the "Capture Current Location" button. It checks location service availability and runtime permissions (`ACCESS_FINE_LOCATION`). It applies a strict 10-second timeout with `LocationAccuracy.high` and falls back gracefully with actionable alerts if permissions are denied or GPS is disabled. Technicians can also enter coordinates manually, with validators ensuring latitude is within `[-90, 90]` and longitude within `[-180, 180]`.

### 10. Multi-Page PDF Generation
**Q: How did you implement multi-page PDF generation in pure Dart?**
> **A:** Using the `pdf` package, `PdfService.generateReport()` builds a `pw.MultiPage` document on an A4 canvas. The `pw.MultiPage` layout automatically handles pagination across headers, tables, and notes. Running page numbers (`Page X of Y`) are generated in `buildFooter`. Completed jobs display a green verified header with the embedded signature image and signer metadata; unfinished jobs display a prominent yellow "DRAFT REPORT" watermark banner. If an image file was deleted from disk, `PdfService` catches the missing file and renders a fallback placeholder rather than crashing the export.

### 11. Android Permissions Across OS Versions
**Q: How do you handle Android storage permissions across Android 12 and Android 13+?**
> **A:** Android 13 (API 33) deprecated `READ_EXTERNAL_STORAGE` in favor of granular media permissions. In `AndroidManifest.xml`, we configure:
> `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />`
> `<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />`
> `image_picker` automatically leverages Android's native Photo Picker on API 33+ without requiring broad storage permissions, while older Android versions fall back cleanly to `READ_EXTERNAL_STORAGE`.

### 12. Signature Canvas & Blank Detection
**Q: How do you detect and reject an empty or accidental signature?**
> **A:** `SignatureScreen` uses `SignatureController`. When the user taps "Confirm Sign-Off", the controller's `controller.isEmpty` property is verified. If the user only tapped a single dot or left the canvas blank, validation displays an error: *"Please provide a customer signature on the canvas."* Once validated, the vector points export to PNG byte data, which `AttachmentService.saveSignatureFile()` writes to disk, returning a durable relative path.

### 13. UI Resilience & Defensive Error Handling
**Q: What happens if an image file on disk is deleted or corrupted while its database record remains?**
> **A:** In `JobDetailScreen` and `PhotoViewScreen`, thumbnails use `Image.file(File(path), errorBuilder: (context, error, stackTrace) => ...)`. If the file is missing or corrupt, it renders a clean fallback card with a broken-image icon and the message *"Image file missing or inaccessible"* rather than throwing an unhandled exception or crashing the UI. Similarly, `PdfService` wraps image resolution in a `try/catch` block and embeds a styled text box placeholder if the image file cannot be read.

### 14. Testing SQLite Without an Android Emulator
**Q: How do you run integration tests on SQLite without spinning up an Android emulator?**
> **A:** We use `sqflite_common_ffi`. In `database_service_test.dart`, `setUpAll()` executes `sqfliteFfiInit()` and assigns `databaseFactory = databaseFactoryFfi;`. We also provided a test hook `DatabaseService.overrideDatabasePath` to point to a temporary local SQLite file (`test_db.db`). This allows full SQLite relational queries, foreign keys, and transactions to run directly on the host machine in milliseconds during CI/CD or local test runs (`flutter test`).

### 15. Schema Migrations & Future Extensibility
**Q: If you need to add a new table or column in a future app version, how does `DatabaseService` support migrations?**
> **A:** `DatabaseService` uses SQLite schema versioning (`version: 1` in `openDatabase()`). The `openDatabase()` callback accepts an `onUpgrade: (db, oldVersion, newVersion) async { ... }` function. For example, if migrating to version 2 to add an `equipment_serial_number` column to `jobs`, `onUpgrade` checks `if (oldVersion < 2) { await db.execute("ALTER TABLE jobs ADD COLUMN equipment_serial_number TEXT;"); }`. Because all queries use parameterized SQL and typed model mappers, models can supply default values for older records.

---

## ⏱️ 3-Minute Live Demo Script

### **Minute 1: The Technician's Morning (Onboarding & Dashboard)**
> *"Good morning. I'd like to show you FieldFlow, an offline-first mobile app designed for field technicians to manage service jobs, inspection checklists, photo evidence, and customer sign-offs without needing an internet connection."*
>
> 1. **Launch App**: *"When launching for the first time, FieldFlow offers a clean onboarding experience. We can start empty or load a pre-configured demo workspace. Let’s load the demo workspace."*
> 2. **Dashboard Overview**: *"Here on the Dashboard, we immediately see today's jobs, in-progress jobs, overdue jobs, and quick metrics. Notice that every summary card is interactive: tapping 'Today' immediately filters the jobs list to today's schedule using our shared `JobsProvider` state."*

### **Minute 2: Active Job Inspection & Photo Evidence**
> *"Now let's step into the shoes of a technician on-site."*
>
> 1. **Open In-Progress Job**: *"Let's select 'Commercial HVAC Quarterly Maintenance'. We see our 4 tabs: Overview, Inspection, Evidence, and Activity."*
> 2. **Execute Checklist**: *"Switching to the Inspection tab, here is our 5-item checklist. Let’s evaluate the 'Check air filter cleanliness' item. I’ll mark it as 'Fail'. Notice that the app immediately requires a comment before saving—field technicians can't fail an item without explaining why. Let's enter: 'Filter heavily clogged with drywall dust'."*
> 3. **Photo Evidence**: *"Now switch to Evidence. We can attach photos from the camera or gallery. Each photo is copied into durable application storage, and we store a relative path in SQLite. Tapping the thumbnail opens a zoomable fullscreen viewer with caption editing."*

### **Minute 3: Completion Blockers, Sign-off & PDF Export**
> *"Now let's try to complete the job."*
>
> 1. **Trigger Completion Blocker**: *"If I tap 'Complete Job' right now, the app blocks the transition with a `CompletionBlockersDialog`. It tells us exactly why: 'Valid customer sign-off signature is required.' This guarantees incomplete work is never submitted."*
> 2. **Customer Sign-off**: *"Let’s tap 'Sign & Complete'. The customer inspects the summary, enters their name ('Sarah Jenkins'), draws their signature on our signature canvas, and confirms. The app validates that the canvas isn't blank, saves the signature PNG, and executes an atomic SQLite transaction updating the status to 'Completed' and recording the history event."*
> 3. **PDF Generation & Share**: *"Finally, let’s tap 'Export PDF'. In under a second, the app compiles a multi-page, publication-ready A4 PDF report with customer info, completed checklist results, notes, photo evidence, and the customer signature. Tapping share opens the native Android share sheet to send the PDF via email, WhatsApp, or Google Drive."*

---

## 📝 2 Factual Resume Bullet Points

- **Built FieldFlow**, an offline-first Flutter/Dart field service management app utilizing SQLite (`sqflite`) with foreign key constraints, atomic status transition transactions, and durable relative file storage for attachments and customer signatures.
- **Engineered** inspection checklist workflows with custom templates, multi-condition completion blocker validation, single-fix GPS capture, and multi-page A4 PDF report generation (`pdf`/`printing`) integrated with the native Android share sheet.

