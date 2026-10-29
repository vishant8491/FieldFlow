import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fieldflow/providers/jobs_provider.dart';
import 'package:fieldflow/screens/job_form_screen.dart';
import 'package:fieldflow/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.overrideDatabasePath = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    DatabaseService.overrideDatabasePath = null;
  });

  Widget createTestWidget(JobsProvider provider) {
    return ChangeNotifierProvider<JobsProvider>.value(
      value: provider,
      child: const MaterialApp(home: JobFormScreen()),
    );
  }

  testWidgets(
    'JobFormScreen: Scheduling without required fields triggers validation errors',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = JobsProvider();
      await tester.pumpWidget(createTestWidget(provider));
      await tester.pumpAndSettle();

      // Find the "Save & Schedule Job" button
      final scheduleButton = find.text('Save & Schedule Job');
      expect(scheduleButton, findsOneWidget);

      await tester.ensureVisible(scheduleButton);
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      // Title validation error should appear
      expect(find.text('Job title is required'), findsOneWidget);
    },
  );

  testWidgets(
    'JobFormScreen: Save as Draft without title displays explanatory snackbar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = JobsProvider();
      await tester.pumpWidget(createTestWidget(provider));
      await tester.pumpAndSettle();

      // Find "Save as Draft (Incomplete)" button
      final draftButton = find.text('Save as Draft (Incomplete)');
      expect(draftButton, findsOneWidget);

      await tester.ensureVisible(draftButton);
      await tester.tap(draftButton);
      await tester.pump();

      // Should display SnackBar stating title is required
      expect(
        find.text('Please enter a job title to save as draft.'),
        findsOneWidget,
      );
    },
  );
}
