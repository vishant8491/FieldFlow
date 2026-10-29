# FieldFlow Requirements Coverage Matrix

| Requirement | Implementation Files | Test / Check | Result | Evidence or Gap |
| :--- | :--- | :--- | :--- | :--- |
| **1. Environment & Setup** | | | | |
| Flutter SDK & Dart environment inspection | `pubspec.yaml`, `android/app/build.gradle.kts` | `flutter --version`, `flutter pub get` | **PASS** | Verified Flutter 3.47.8, Dart 3.13.7. Clean dependency resolution with zero errors. |
| Code formatting standards | All `lib/` and `test/` Dart files | `dart format --output=none --set-exit-if-changed lib test` | **PASS** | Formatted all 35 project files. Verification passes with 0 changed files. |
| Static analysis & lint rules | `analysis_options.yaml`, all `lib/` Dart files | `dart analyze lib test` | **PASS** | 0 warnings, 0 errors, 0 lints across all library and test source code. |
| Primary target platform configuration | `android/app/src/main/AndroidManifest.xml` | Build config inspection | **PASS** | Target SDK, permissions for Camera, Storage, Location configured properly. |
| **2. Onboarding & Demo Data** | | | | |
| Onboarding first-run display | `lib/screens/onboarding_screen.dart`, `lib/providers/jobs_provider.dart` | Manual inspection / Widget flow | **PASS** | Shows on first launch when preference `onboarding_completed` is false. |
| Start Empty option | `lib/screens/onboarding_screen.dart`, `lib/providers/jobs_provider.dart` | `JobsProvider.completeOnboarding(loadDemo: false)` | **PASS** | Flags onboarding as completed, creates zero seed jobs/customers, leaves clean workspace. |
| Load Demo Workspace option | `lib/screens/onboarding_screen.dart`, `lib/services/database_service.dart` | `DatabaseService.loadDemoData()` | **PASS** | Seeds 5 realistic jobs across statuses (Draft, Scheduled, In Progress, Completed, Cancelled). |
| Synthetic customer details | `lib/services/database_service.dart` | `_demoCustomers` inspection | **PASS** | All demo customers use synthetic names, fake 555 numbers, and example.com domains. |
| Reopening preserves demo status | `lib/services/database_service.dart` | Preferences table & flag checks | **PASS** | `demo_data_loaded` preference prevents duplicate seeding on subsequent launches. |
| Deleted demo data not restored | `lib/services/database_service.dart` | Preferences persistence check | **PASS** | Deleting jobs/customers retains `demo_data_loaded=1`; demo records are never re-injected. |
| **3. Customer Management** | | | | |
| Create customer with validation | `lib/screens/customer_form_screen.dart`, `lib/models/customer.dart` | Form validation & `DatabaseService.insertCustomer` | **PASS** | Trims name and phone; rejects empty inputs; validates optional email regex format. |
| Edit existing customer | `lib/screens/customer_form_screen.dart` | `DatabaseService.updateCustomer` | **PASS** | Updates name, phone, email and immediately reflects in customer directory and job selectors. |
| Safe deletion guard | `lib/screens/customers_screen.dart`, `lib/services/database_service.dart` | `DatabaseService.deleteCustomer` FK check | **PASS** | Queries active jobs referencing customerId; aborts deletion with friendly warning if jobs exist. |
| Customer listing & search | `lib/screens/customers_screen.dart` | `CustomerListScreen` query & filtering | **PASS** | Lists customers alphabetically; filters in real-time by name or phone query. |
| **4. Job Creation & Form Validation** | | | | |
| Save incomplete draft job | `lib/screens/job_form_screen.dart`, `lib/models/service_job.dart` | Widget test & provider verification | **PASS** | Allows saving with only a title; customer, address, and date are optional for Draft status. |
| Scheduling requires customer, address, date | `lib/screens/job_form_screen.dart` | `test/job_form_validation_test.dart` | **PASS** | Inline form errors block scheduling if customer is unselected, address is blank, or date is null. |
| Coordinate validation & bounds | `lib/services/location_service.dart`, `lib/screens/job_form_screen.dart` | `test/workflow_rules_test.dart` (D1 fix) | **PASS** | Enforces latitude in [-90, 90], longitude in [-180, 180]; strictly rejects NaN, Infinity, -Infinity. |
| Saving scheduled job updates status | `lib/screens/job_form_screen.dart` | `test/integration_workflow_test.dart` (D2 fix) | **PASS** | Form correctly assigns `JobStatus.scheduled` when clicking "Save & Schedule Job". |
| Prevent duplicate submissions | `lib/screens/job_form_screen.dart` | `_isSaving` guard flag check | **PASS** | Disables save buttons and ignores concurrent taps while async database write is in progress. |
| Preserve input on save error | `lib/screens/job_form_screen.dart` | Form state inspection | **PASS** | Text controllers retain user input if database write fails; error banner displayed. |
| Unsaved changes warning | `lib/screens/job_form_screen.dart` | `PopScope(canPop: ...)` implementation | **PASS** | Prompts confirmation dialog if user attempts to pop back with unsaved edits. |
| Safe date/time cancellation | `lib/screens/job_form_screen.dart` | DatePicker & TimePicker null checks | **PASS** | Cancelling picker dialog returns null without overwriting or clearing existing scheduled date. |
| **5. Status Rules & State Machine** | | | | |
| Normal progression Draft -> Scheduled -> In Progress -> Completed | `lib/providers/jobs_provider.dart`, `lib/models/service_job.dart` | `test/workflow_rules_test.dart`, `test/integration_workflow_test.dart` | **PASS** | Enforces valid status sequence; rejects skipping (e.g. Draft -> In Progress or Completed). |
| Cancellation rules | `lib/providers/jobs_provider.dart` | `test/workflow_rules_test.dart` (D3 fix) | **PASS** | Only unfinished jobs (Draft, Scheduled, In Progress) can be cancelled; requires non-blank reason. |
| Reopening completed jobs | `lib/providers/jobs_provider.dart`, `lib/services/database_service.dart` | `test/integration_workflow_test.dart` | **PASS** | Transitions status back to `inProgress`; logs audit event; requires non-blank reason. |
| Atomic status transition & audit log | `lib/services/database_service.dart`, `lib/models/status_event.dart` | `test/database_service_test.dart` | **PASS** | Job status update and status history insertion are executed in a single SQLite transaction. |
| Read-only enforcement on Completed jobs | `lib/screens/job_detail_screen.dart` | UI actions hidden & mutation paths locked | **PASS** | Editing job, checklist results, notes, photos, and signatures are disabled when completed. |
| Re-completion blocked after reopen | `lib/providers/jobs_provider.dart`, `lib/screens/job_detail_screen.dart` | `test/integration_workflow_test.dart` | **PASS** | Previous sign-off marked noncurrent; completion rules require a fresh customer sign-off. |
| **6. Inspection Checklists & Templates** | | | | |
| Standard checklist templates | `lib/services/database_service.dart` | Database schema seed & template selector | **PASS** | Ships default templates (HVAC, Electrical, Plumbing, Fire & Safety); imports into active job. |
| Checklist item result recording | `lib/screens/job_detail_screen.dart`, `lib/models/checklist_item.dart` | `test/integration_workflow_test.dart` | **PASS** | Supports Pending, Pass, Fail, Not Applicable with immediate database update. |
| Fail requires comment | `lib/screens/job_detail_screen.dart`, `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Dialog requires comment before saving Fail result; completion blocked if comment empty. |
| Not Applicable on required requires reason | `lib/screens/job_detail_screen.dart`, `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Dialog requires reason before saving N/A result on required items; completion blocked if empty. |
| Checklist item reordering | `lib/screens/job_detail_screen.dart`, `lib/providers/jobs_provider.dart` | `test/integration_workflow_test.dart` (D5 fix) | **PASS** | `ReorderableListView` enabled for active jobs; updates sortOrder in database and provider. |
| Custom checklist items | `lib/screens/job_detail_screen.dart` | Add custom item dialog | **PASS** | Allows adding ad-hoc required or optional checklist items during job execution. |
| **7. Photos & Durable File Safety** | | | | |
| Durable relative path storage | `lib/services/attachment_service.dart`, `lib/models/attachment.dart` | `test/file_safety_test.dart` | **PASS** | Stores relative paths (`attachments/...`); resolves dynamically to sandbox app documents path. |
| Image capture & import | `lib/services/attachment_service.dart`, `image_picker` | `JobDetailScreen._addPhoto` | **PASS** | Imports photo from camera or gallery; writes copy to app storage; records metadata. |
| Orphaned file cleanup on DB failure | `lib/screens/job_detail_screen.dart`, `lib/screens/signature_screen.dart` | Code verification & error simulation (D4 fix) | **PASS** | Catches SQLite error and immediately deletes copied image/signature file from disk. |
| Attachment safe deletion | `lib/services/attachment_service.dart`, `lib/services/database_service.dart` | `test/file_safety_test.dart` | **PASS** | Removes file from filesystem and deletes database row cleanly. |
| Total storage calculation | `lib/services/attachment_service.dart` | `test/file_safety_test.dart` | **PASS** | Computes storage bytes across attachments and signatures; displays in Settings. |
| **8. Customer Sign-off** | | | | |
| Canvas signature capture | `lib/screens/signature_screen.dart` | `SignatureScreen` canvas interaction | **PASS** | CustomPainter captures stroke paths; converts to PNG bytes upon confirmation. |
| Non-empty signature validation | `lib/screens/signature_screen.dart` | Canvas stroke count & non-empty check | **PASS** | Blocks confirmation if canvas is blank or signer name is omitted. |
| Sign-off persistence & current flag | `lib/models/sign_off.dart`, `lib/services/database_service.dart` | `test/integration_workflow_test.dart` | **PASS** | Saves signer name, timestamp, signature PNG file; flags `isCurrent=1`. |
| Reopening marks sign-off noncurrent | `lib/services/database_service.dart` | `test/integration_workflow_test.dart` | **PASS** | Explicit reopen updates `isCurrent=0` on existing sign-off records; preserves history. |
| **9. Completion Blockers & Rules** | | | | |
| Pending required items block completion | `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Identifies all pending required items and displays them as blockers in UI. |
| Missing Fail comments block completion | `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Flags failed items lacking explanatory comments as completion blockers. |
| Missing N/A reasons block completion | `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Flags required N/A items lacking justification as completion blockers. |
| Missing sign-off blocks completion | `lib/providers/jobs_provider.dart` | `test/completion_blockers_widget_test.dart` | **PASS** | Flags missing current sign-off as a completion blocker. |
| Exhaustive blocker summary modal | `lib/screens/job_detail_screen.dart` | `JobDetailScreen._showCompletionBlockers` | **PASS** | Displays all blockers together in a structured modal dialog before allowing completion. |
| **10. PDF Service Report** | | | | |
| Multi-page report generation | `lib/services/pdf_service.dart` | `test/pdf_service_test.dart`, `test/integration_workflow_test.dart` | **PASS** | Generates valid PDF bytes; renders branded header, customer metadata, schedule, and status. |
| Location rendering in PDF | `lib/services/pdf_service.dart` | `test/pdf_service_test.dart` | **PASS** | Renders GPS coordinates and capture timestamp if present; omits cleanly if null. |
| Checklist item results summary | `lib/services/pdf_service.dart` | `test/pdf_service_test.dart` | **PASS** | Renders table of all checklist items with status badges, comments, and reasons. |
| Photos & Signatures in PDF | `lib/services/pdf_service.dart` | `test/pdf_service_test.dart` | **PASS** | Embeds attached photo thumbnails with captions and customer signature image. |
| Sharing & Printing integration | `lib/screens/pdf_preview_screen.dart`, `printing` package | `PdfPreviewScreen` action buttons | **PASS** | Uses `printing.Printing.layoutPdf` and `Printing.sharePdf` for direct system interaction. |
| **11. Dashboard, Metrics & Jobs List** | | | | |
| Metric counters accuracy | `lib/screens/dashboard_screen.dart`, `lib/providers/jobs_provider.dart` | Metric card calculations | **PASS** | Correctly counts Today, Upcoming, Overdue, and Completed jobs. |
| Exclude Drafts from scheduled metrics | `lib/providers/jobs_provider.dart` | Unit calculation & filter verification | **PASS** | `todayJobs` and `upcomingJobs` exclude `JobStatus.draft` and handle end-of-day boundaries. |
| Search & status filter | `lib/screens/jobs_screen.dart` | Search input & filter chip selection | **PASS** | Filters jobs list by title, customer name, and status chips in real time. |
| Priority and date sorting | `lib/screens/jobs_screen.dart`, `lib/providers/jobs_provider.dart` | `JobsProvider.sortJobs` | **PASS** | Sorts by scheduled date (Asc/Desc), Priority (High to Low), or Status; drafts ordered last in Asc. |
| **12. Database Integrity & Storage Safety** | | | | |
| Schema versioning & migrations | `lib/services/database_service.dart` | `onUpgrade` hook & versioning | **PASS** | Schema v1 with table definitions and future migration architecture documented. |
| Foreign key enforcement | `lib/services/database_service.dart` | `PRAGMA foreign_keys = ON;` | **PASS** | Foreign keys enabled on every SQLite database connection. |
| Parameterized SQL queries | `lib/services/database_service.dart` | Query code audit | **PASS** | 100% of SQLite read/write operations use parameterized `?` placeholders (no SQL injection). |
| Complete database reset / purge | `lib/services/database_service.dart`, `lib/services/attachment_service.dart` | Settings reset & `test/file_safety_test.dart` | **PASS** | Purges all SQLite tables and deletes all physical files in attachments/signatures directories. |
| **13. Hardware & Platform Verification** | | | | |
| Real Camera hardware photo capture | `image_picker` platform channel | Physical Android device test | **NOT RUN** | Host environment has no attached physical Android device. Verified via unit/widget tests. |
| Real GPS location hardware capture | `geolocator` platform channel | Physical Android device test | **NOT RUN** | Host environment has no attached physical Android device. Validated logic and coordinate bounds. |
| Android System Share Sheet intent | `share_plus` / `printing` platform channels | Physical Android device test | **NOT RUN** | Android OS intent verification requires physical device or running emulator. Code reviewed. |
| APK production build artifact | `gradlew assembleRelease` | Release build command | **BLOCKED** | Sandbox environment lacks network access to `dl.google.com` to fetch Kotlin Gradle plugins. |
| In-memory & Desktop execution | `sqflite_common_ffi`, Flutter desktop | Automated test suite & desktop run | **PASS** | All business logic, UI screens, PDF generation, and SQLite engines fully tested and passing. |

