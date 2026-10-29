# FieldFlow — Offline Field Service & Inspection Management

**FieldFlow** is a professional, offline-first application built with **Flutter & Dart** designed for field service technicians, safety inspectors, and maintenance engineers. It streamlines daily operations by managing work orders, executing structured safety and maintenance checklists, capturing photo evidence, collecting customer sign-offs, and generating publication-ready multi-page PDF service reports directly on the device or browser.

FieldFlow operates entirely offline with zero cloud dependencies, external servers, paid APIs, or user logins. All customer records, job lifecycles, inspection items, photos, and signatures persist locally in SQLite and durable storage with referential integrity and strict transaction boundaries.

---

## 🛠️ Architecture & Tech Stack

| Component | Technology | Rationale / Purpose |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.47+ & Dart 3.13+** | Cross-platform UI toolkit targeting native Android runtime and mobile/desktop browsers. |
| **State Management** | **Provider (`ChangeNotifier`) + `setState`** | Straightforward, transparent separation of concerns: global app state lives in `JobsProvider` and `ThemeProvider`, while ephemeral UI states (forms, tab indexes, zoom levels) stay local in `setState`. No over-engineered Bloc, Riverpod, or code-generation. |
| **Local Database** | **SQLite via `sqflite` (Android) & `sqflite_common_ffi_web` (Web)** | Relational schema with 9 tables, foreign key constraints, parameterized SQL queries, index optimization, and atomic transaction handling. On Web, executes SQLite via WebAssembly (`sqlite3.wasm`) and worker (`sqflite_sw.js`) backed by browser IndexedDB. |
| **Binary Storage** | **`path_provider` (Android) & `idb_shim` (Web)** | Persistent app storage for attachments and signatures. SQLite stores durable relative paths (`attachments/...`, `signatures/...`), insulating the app against sandbox path shifts. On Web, binary data is stored as raw byte blobs in IndexedDB. |
| **Camera & Gallery** | **`image_picker`** | Captures photos or imports from device gallery with Android process loss recovery via `ImagePicker.retrieveLostData()` and responsive file pickers in modern browsers. |
| **Device Location** | **`geolocator`** | Single-fix GPS coordinate acquisition with comprehensive permission handling (granted, denied, permanently denied) and manual coordinate fallback with strict range validation (`-90..90`, `-180..180`). Explains HTTPS browser requirements on Web. |
| **Digital Sign-off** | **`signature`** | Touch and pointer canvas for capturing customer signature strokes, validating non-empty input, and rendering durable PNG files. Touch events are isolated to prevent scroll hijacking on mobile browsers. |
| **PDF Generation & Export** | **`pdf` & `printing`** | High-performance multi-page A4 document generation with tables, headers, running page numbers, photo evidence grids, and integration with Android's share sheet (`share_plus`) or direct browser download on Web. |
| **Design System** | **Material 3** | Professional design system featuring Dark Slate (`#0F172A`), Cobalt Blue (`#2563EB`), and restrained Amber accents (`#D97706`), supporting full Light and Dark themes. |

---

## 📋 Core Workflow & Status Lifecycle

FieldFlow enforces strict state machine transitions to protect data integrity:

```
[Draft] ----------> [Scheduled] ----------> [In Progress] ----------> [Completed] (Read-Only)
   |                     |                        |                         |
   +---------------------+------------------------+                         |
   |                                                                        |
   v                                                                        |
[Cancelled] (Requires Reason)                                              |
                                                                            |
   <----------------------------- Reopened ---------------------------------+
                         (Invalidates Previous Sign-off,
                           Requires Reason & Re-sign)
```

### Lifecycle Rules:
1. **Draft -> Scheduled**: Requires a valid customer, street address, and scheduled date/time.
2. **Scheduled -> In Progress**: Initiates active work and enables the inspection checklist.
3. **In Progress -> Completed**: Enforces strict completion blockers:
   - Every required checklist item must have a recorded result (`Pass`, `Fail`, or `Not Applicable`).
   - Any `Fail` requires an explanatory technician comment.
   - Any `Not Applicable` on a required item requires a valid explanation.
   - A non-empty customer signature and signer name must be captured.
   - All blockers are surfaced clearly in the `CompletionBlockersDialog` before transition.
4. **Cancellation**: Permitted from any non-completed state, but strictly requires a recorded cancellation reason.
5. **Immutability of Completed Jobs**: Completed jobs are read-only. Forms, checklist evaluators, and attachment controls are disabled.
6. **Explicit Reopening**: A completed job may be reopened with a mandatory reason. In a single atomic SQLite transaction, the status reverts to `In Progress`, the reopening event is logged in `status_history`, and the prior sign-off is marked `is_current = 0`, forcing a new signature before the job can be completed again.

---

## ✨ Features Walkthrough

### 1. Onboarding & Demo Workspace
- Welcome onboarding flow explaining offline-first architecture.
- **"Start Empty"** mode for a completely clean production workspace.
- **"Load Demo Workspace"** option populating realistic synthetic jobs, customers, and checklists across all status stages.
- Re-opening the app persists onboarding state and avoids duplicate seeding.

### 2. Service Job Management & Customer Directory
- Create, search, filter, and sort jobs by Scheduled Date, Priority (High/Medium/Low), or Status.
- Manage customer contact details with validation (trimmed strings, phone requirements, optional RFC-compliant email).
- Foreign key protection: customers with active service jobs cannot be accidentally deleted.

### 3. Inspection Checklists & Reusable Templates
- Pre-loaded industry templates (HVAC Standard, Electrical Safety, Plumbing Inspection, Fire & Safety).
- Apply templates or create custom inspection checklists with drag-and-drop reordering.
- Enforces checklist results: `Pass`, `Fail` (mandatory comment), and `Not Applicable` (mandatory justification for required items).

### 4. Photo Evidence & Durable Attachment Storage
- Geotagged photo capture via camera or device gallery.
- Captions and timestamps recorded with each photo attachment.
- Automatic disk/storage cleanup on database failure to prevent orphaned storage leaks.

### 5. Customer Digital Sign-off
- Interactive signature drawing canvas with stroke validation.
- Validates non-empty signature drawing and signer full name.
- Explicit legal operational acknowledgment disclaimer (does not claim certified cryptographic identity).

### 6. Branded Multi-Page PDF Service Reports
- Generates professional multi-page A4 service reports on device.
- Renders job metadata, schedule, GPS coordinates, customer details, complete inspection item results with comments, photo evidence gallery, status timeline, and customer signature image.
- Direct system sharing or browser file download.

---

## 🌐 Web Browser & PWA Support

FieldFlow runs seamlessly in desktop and mobile web browsers:
- **True Web Persistence**: Built with `sqflite_common_ffi_web` (SQLite compiled to WebAssembly) and `idb_shim` (IndexedDB binary storage). Data survives browser refreshes (`F5`), tab re-openings, and browser restarts.
- **Cross-Origin Isolation**: Ships with `coi-serviceworker.js` to enable `SharedArrayBuffer` on static hosts like GitHub Pages without requiring custom server response headers.
- **Responsive Mobile Web Experience**: Configured with mobile-first viewport meta tags (`width=device-width, initial-scale=1.0`), touch-friendly targets, and gesture isolation on the signature canvas.

> **Note on Browser Storage**: Web data is saved locally in your browser's IndexedDB and is completely independent from physical Android devices (no cloud synchronization). Clearing browser site data or using private/incognito mode will reset the local browser workspace.

---

## 🧪 Automated Testing & Verification

FieldFlow includes comprehensive automated test coverage with **22 / 22 tests passing**:

```powershell
# Run the complete test suite
flutter test --concurrency=1
```

### Verified Test Suites:
1. **`test/integration_workflow_test.dart`** (1 test, 13 lifecycle stages):
   - Full end-to-end technician journey: Customer creation -> Draft job -> Schedule -> Start -> Apply template -> Reorder items -> Assess checklist (Pass, Fail with comment, N/A with reason) -> Attach photo -> Capture sign-off -> Complete job -> Multi-page PDF generation -> Close & reopen database -> Reopen job with reason -> Verify sign-off invalidated and re-completion blocked.
2. **`test/workflow_rules_test.dart`** (10 tests):
   - Validates status transitions, state machine guards, cancellation rules, completion blockers, and coordinate range limits (`-90..90`, `-180..180`).
3. **`test/database_service_test.dart`** (4 tests):
   - Tests SQLite foreign key restrictions, atomic status transition transactions, and sign-off invalidation on reopen.
4. **`test/file_safety_test.dart`** (2 tests):
   - Tests durable relative path resolution, disk storage calculation, and directory cleanup hooks.
5. **`test/web_storage_compatibility_test.dart`** (2 tests):
   - Tests cross-platform relative path formatting and byte storage operations.
6. **`test/job_form_validation_test.dart`** (2 tests):
   - Widget tests for inline form validation errors and draft persistence.
7. **`test/completion_blockers_widget_test.dart`** (1 test):
   - Widget test for the `CompletionBlockersDialog` modal.
8. **`test/pdf_service_test.dart`** (1 test):
   - Multi-page PDF generation stress test without native disk dependencies.

---

## 🚀 Building & Running

### Prerequisites:
- **Flutter SDK**: 3.47.8 or higher
- **Dart SDK**: 3.13.7 or higher
- **Android SDK**: compileSdk 34+, minSdk 21+
- **Java**: JDK 17

### Development Commands:
```powershell
# Format code
dart format lib test

# Static analysis (0 issues)
flutter analyze lib test

# Run automated tests
flutter test --concurrency=1

# Run on connected Android phone / emulator
flutter run

# Run in Chrome browser
flutter run -d chrome

# Build release Web bundle
flutter build web --release

# Build release Android APK
flutter build apk --release
```

---

## 🚀 Deploying to GitHub Pages

FieldFlow includes a ready-to-run GitHub Actions deployment workflow in `.github/workflows/deploy_web.yml`.

To deploy:
1. Push the repository to GitHub.
2. Navigate to **Settings** -> **Pages** in the GitHub repository.
3. Under **Build and deployment** -> **Source**, select **GitHub Actions**.
4. The workflow will automatically test, compile WebAssembly assets, and publish your live app at:
   `https://<username>.github.io/<repository-name>/`
