# FieldFlow — Code Architecture & Technical Walkthrough

FieldFlow is an offline-first mobile service management application built with Flutter, Provider, SQLite (`sqflite`), and Material 3. It is designed for field technicians to manage service jobs, execute standardized inspection checklists, capture photo evidence, obtain customer signatures, and generate comprehensive PDF reports without network connectivity.

---

## 1. Main Files & Directory Structure

```text
lib/
  main.dart                           # App root, MultiProvider registration, splash & onboarding router
  models/
    customer.dart                     # Customer data model (ID, name, phone, optional email)
    service_job.dart                  # Service job model, JobPriority & JobStatus enums, color helpers
    checklist_item.dart               # Checklist item model, ChecklistResult enum (Pass, Fail, N/A, Pending)
    attachment.dart                   # Photo attachment model (relativePath, caption, timestamps)
    job_note.dart                     # Technician field note model
    status_event.dart                 # Status transition history event model
    sign_off.dart                     # Customer signature acknowledgement model (signerName, isCurrent)
    checklist_template.dart           # Reusable template model
    template_item.dart                # Template item model (label, isRequired, sortOrder)
  services/
    database_service.dart             # SQLite singleton with schema versioning & atomic transactions
    attachment_service.dart           # Durable photo/signature file manager under app documents directory
    location_service.dart             # On-demand GPS coordinates capture and validation service
    pdf_service.dart                  # Multi-page PDF report generation with printing & share_plus
    demo_data_seeder.dart             # Default templates & synthetic interview demo workspace seeder
  providers/
    jobs_provider.dart                # Core business logic, status transitions, blockers, filtered lists
    theme_provider.dart               # ThemeMode state (System, Light, Dark) persisted in SQLite preferences
  screens/
    home_screen.dart                  # IndexedStack root with bottom navigation (Dashboard, Jobs, Templates)
    dashboard_screen.dart             # Today's, upcoming, overdue metrics, quick filters, recent activity
    jobs_screen.dart                  # Search, status/priority/date filter chips, sort options, job list
    job_form_screen.dart              # Create/edit job form with inline validation, GPS capture, draft mode
    job_detail_screen.dart            # Multi-tab view: Overview, Inspection, Evidence, Activity / Sign-off
    inspection_item_dialog.dart       # Pass/Fail/NA evaluation with required comment/reason validation
    signature_screen.dart             # Signature canvas with empty detection, preview, and durable saving
    photo_view_screen.dart            # Full-screen photo viewer with zoom, caption, and safe deletion
    customer_form_screen.dart         # Create/edit customer dialog with contact validation
    templates_screen.dart             # Saved reusable templates manager
    template_form_screen.dart         # Create/edit template and reorderable item list
    settings_screen.dart              # Theme switcher, storage usage meter, data reset confirmation
    onboarding_screen.dart            # First-run welcome screen (Load Demo Workspace vs Start Empty)
  widgets/
    completion_blockers_dialog.dart   # Dedicated dialog displaying exact unmet completion requirements
  utils/
    app_theme.dart                    # Material 3 dark slate, cobalt blue, and amber color themes
```

---

## 2. Application Startup Flow

```
main()
  │
  ├── WidgetsFlutterBinding.ensureInitialized()
  │
  └── runApp(FieldFlowApp)
        │
        ├── MultiProvider
        │     ├── ChangeNotifierProvider: ThemeProvider
        │     └── ChangeNotifierProvider: JobsProvider
        │
        └── Consumer<ThemeProvider>
              │
              └── MaterialApp
                    │
                    └── AppEntryPoint
                          │
                          ├── jobsProvider.isLoading == true
                          │     └── Splash Loading Indicator
                          │
                          ├── jobsProvider.onboardingCompleted == false
                          │     └── OnboardingScreen (Load Demo Workspace vs Start Empty)
                          │
                          └── jobsProvider.onboardingCompleted == true
                                └── HomeScreen (IndexedStack: Dashboard, Jobs, Templates)
```

1. **`main()`** registers Flutter widget bindings and starts `FieldFlowApp`.
2. **`ThemeProvider`** immediately loads the stored `'themeMode'` preference from SQLite (`'system'`, `'light'`, or `'dark'`).
3. **`JobsProvider`** queries SQLite preferences for `'onboardingCompleted'` and `'demoDataLoaded'`, and loads the initial customers, templates, and jobs.
4. **`AppEntryPoint`** checks `jobsProvider.isLoading`. While data is being retrieved, it displays a clean progress indicator.
5. If onboarding is not completed, `OnboardingScreen` welcomes the user. Once the user taps **Load Demo Workspace** or **Start Clean Workspace**, preferences are saved to SQLite, and `AppEntryPoint` transitions to `HomeScreen`.

---

## 3. Button → Provider → SQLite → UI Data Flow Trace

When a technician marks a checklist item or updates a job, the architecture follows an explicit, unidirectional flow:

```
[ User Interaction ]
       │
       ▼  (e.g., Taps "Complete Job" on JobDetailScreen)
[ Screen / Widget ]
       │
       ▼  Calls Provider method with typed arguments
[ JobsProvider.transitionJobStatus() ]
       │
       ├─ Validates business workflow rules:
       │    • Job must be in In Progress status
       │    • All required checklist items evaluated
       │    • Fail items have comments; N/A items have justification
       │    • Customer sign-off exists with non-empty signature & name
       │
       ▼  If valid, delegates database mutation
[ DatabaseService.updateJobStatusWithTransaction() ]
       │
       ├─ Begins SQLite Transaction:
       │    1. Updates `status` and `completedAt` on `jobs` table
       │    2. Inserts audit event into `status_history` table
       │    3. Commits transaction atomically
       │
       ▼  Returns to Provider
[ JobsProvider.loadJobs() ]
       │
       ├─ Queries fresh jobs list from SQLite
       ├─ Updates `_allJobs`
       │
       ▼  Calls notifyListeners()
[ ChangeNotifier / Provider ]
       │
       ▼  Notifies listening widgets
[ Consumer / context.watch() ]
       │
       ▼  Rebuilds UI with updated status chip, completed badges, read-only locks
[ Screen UI Updates ]
```

---

## 4. `setState` versus `Provider`

FieldFlow adheres to a strict separation of concerns between temporary screen-level state and shared application state:

| State Scope | Tool Used | Usage Scenarios in FieldFlow |
| :--- | :--- | :--- |
| **Local Screen State** | `setState` | Form input controllers (`_titleController`), active tab index in `HomeScreen`, signature canvas clearing, dialog validation error strings (`_commentError`), photo full-screen loading flag, unsaved modification tracking (`_hasModified`). |
| **Shared Application State** | `Provider` (`ChangeNotifier`) | Persistent lists of jobs, customers, and templates; active search query and filter criteria; global theme mode (`ThemeProvider`); business workflow rule evaluation and SQLite mutation dispatches. |

This pattern keeps the provider lean and avoids unnecessary widget rebuilds across unrelated screens when a user types into a text field.

---

## 5. Status Transition Rules & Atomic Transactions

FieldFlow implements an explicit state machine for service jobs:

```
       ┌──────────────────┐
       │      Draft       │
       └────────┬─────────┘
                │ (Requires valid customer, address & schedule)
                ▼
       ┌──────────────────┐
       │    Scheduled     │
       └────────┬─────────┘
                │ (Technician starts work)
                ▼
       ┌──────────────────┐
       │   In Progress    │◄─────────────────────────────┐
       └────────┬─────────┘                              │
                │ (Requires all checklist items resolved │ (Explicit Reopen with reason:
                │  & valid customer sign-off)            │  invalidates previous sign-off)
                ▼                                        │
       ┌──────────────────┐                              │
       │    Completed     ├──────────────────────────────┘
       └──────────────────┘

* Note: Any unfinished job (Draft, Scheduled, In Progress) can be Cancelled,
  but ONLY with a non-empty cancellation reason.
```

### Atomic Transactions

All status mutations use SQLite transactions (`db.transaction((txn) async { ... })`):
- **Status Change**: The job's status and timestamp are updated, and a `status_history` row is inserted in the exact same transaction.
- **Reopening a Completed Job**:
  1. All existing sign-offs for the job are updated to `isCurrent = 0`.
  2. The job status is updated to `JobStatus.inProgress`, and `completedAt` is set to `null`.
  3. A new `status_history` entry is recorded with the technician's reopening reason.
  4. If any step fails, the entire transaction rolls back, preventing inconsistent audit history.

---

## 6. Android Permission Handling

FieldFlow handles hardware permissions gracefully through explicit user interactions:

1. **Camera**:
   - Permission `android.permission.CAMERA` is declared in `AndroidManifest.xml`.
   - Requested only when the technician taps "Take Photo with Camera".
   - If denied, image picker returns `null`, handled without crashing.
   - Android lost-data recovery is supported via `AttachmentService.retrieveLostData()`.
2. **Gallery / Photos**:
   - `READ_EXTERNAL_STORAGE` (maxSdk 32) and `READ_MEDIA_IMAGES` (API 33+) are declared.
   - Modern Android Photo Picker is utilized when available, minimizing permission friction.
3. **Location (GPS)**:
   - `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` are declared.
   - Location is captured **only upon explicit button tap** in the job form ("Acquire GPS").
   - If services are disabled: prompts the user to enable device GPS.
   - If denied: notifies technician via SnackBar.
   - If permanently denied: directs technician to manual latitude/longitude entry fields with inline coordinate range validation (`-90..90`, `-180..180`).
   - The app remains 100% usable if location is unavailable or denied.

---

## 7. Durable Local File Storage Architecture

FieldFlow stores binary assets (camera photos, gallery uploads, customer signature PNGs) in app-managed durable storage rather than caching raw paths:

```
[Device Internal Storage]
└── /data/user/0/com.fieldflow.fieldflow/app_flutter/ (getApplicationDocumentsDirectory())
    ├── attachments/
    │   ├── job_1_1698765432000.jpg
    │   └── job_2_1698765499000.jpg
    └── signatures/
        ├── sig_1_1698765432100.png
        └── sig_2_1698765499100.png
```

- **Relative Paths**: Only relative paths (e.g. `attachments/job_1_1698765432000.jpg`) are saved in the SQLite `attachments` and `sign_offs` tables. This guarantees path resolution remains intact across application updates or OS backup restores.
- **Deletion Cleanup**: When an attachment is deleted from a job, `AttachmentService.deleteFile(relativePath)` removes the file from disk immediately.
- **Workspace Reset**: "Clear All App Data" in Settings recursively deletes both the `attachments/` and `signatures/` directories, preventing orphaned media files from consuming device storage.

---

## 8. PDF Report Generation & Sharing

PDF generation is handled by `PdfService`:
1. **Multi-Page Layout**: Built using `pdf/widgets.dart` `pw.MultiPage`. Automatically handles page breaking, headers, and footers with dynamic page numbering ("Page X of Y").
2. **Draft Watermark / Badge**: Unfinished jobs are clearly flagged with an amber "DRAFT REPORT" banner; completed jobs feature a green "COMPLETED SERVICE REPORT" header.
3. **Structured Content**: Includes Report ID, customer contact, address, schedule, GPS coordinates, inspection checklist results table, technician notes, customer sign-off signature with legal operational disclaimer, and the status transition audit trail.
4. **Photo Embedding & Missing-File Fallback**: Attachment images are pre-loaded from internal storage. If a file was removed outside the app, a formatted `[Missing Image]` placeholder box is rendered instead of throwing an error.
5. **Platform Sharing**: Tapping the PDF icon calls `PdfService.shareReportPdf()`, which invokes `Printing.sharePdf()` to summon the native Android share sheet (Email, Drive, WhatsApp, Bluetooth).

---

## 9. How to Add a New Job Field (Step-by-Step Guide)

Suppose you want to add an `equipmentSerialNumber` (String?) field to service jobs:

### Step 1: Update SQLite Database Schema (`lib/services/database_service.dart`)
1. In `_onCreate`:
   ```sql
   equipmentSerialNumber TEXT,
   ```
2. In `_onUpgrade`, handle existing installs:
   ```dart
   if (oldVersion < 2) {
     await db.execute('ALTER TABLE jobs ADD COLUMN equipmentSerialNumber TEXT');
   }
   ```
3. Bump `databaseVersion = 2`.

### Step 2: Update Model (`lib/models/service_job.dart`)
1. Add field: `final String? equipmentSerialNumber;`
2. Update constructor: `this.equipmentSerialNumber,`
3. Update `toMap()`: `'equipmentSerialNumber': equipmentSerialNumber?.trim(),`
4. Update `fromMap()`: `equipmentSerialNumber: map['equipmentSerialNumber'] as String?,`
5. Update `copyWith()`: `String? equipmentSerialNumber,`

### Step 3: Update Job Form (`lib/screens/job_form_screen.dart`)
1. Add controller: `late TextEditingController _serialController;`
2. Initialize in `initState()` and dispose in `dispose()`.
3. Add `TextFormField` in `build()`:
   ```dart
   TextFormField(
     controller: _serialController,
     decoration: const InputDecoration(labelText: 'Equipment Serial #', prefixIcon: Icon(Icons.qr_code_rounded)),
   )
   ```
4. Include `equipmentSerialNumber: _serialController.text.trim()` in `ServiceJob(...)` creation.

### Step 4: Display in Detail Screen & PDF Report
1. In `lib/screens/job_detail_screen.dart` (`_buildOverviewTab`), display the serial number card if present.
2. In `lib/services/pdf_service.dart`, add `_buildDetailRow('Serial #:', job.equipmentSerialNumber ?? 'N/A')` under the overview section.

