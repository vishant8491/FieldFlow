import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fieldflow/widgets/completion_blockers_dialog.dart';

void main() {
  testWidgets(
    'CompletionBlockersDialog renders all blockers and dismisses on Understood',
    (tester) async {
      final blockers = [
        '2 required inspection checklist item(s) are still pending.',
        'Checklist item "Compressor Seal" failed without an explanatory comment.',
        'Customer sign-off and signature are missing.',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        CompletionBlockersDialog(blockers: blockers),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Initial state: no dialog
      expect(find.text('Completion Blockers'), findsNothing);

      // Tap button to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog title and header
      expect(find.text('Completion Blockers'), findsOneWidget);
      expect(
        find.text(
          'The following requirements must be resolved before this job can be marked completed:',
        ),
        findsOneWidget,
      );

      // Verify all blockers are displayed
      for (final blocker in blockers) {
        expect(find.text(blocker), findsOneWidget);
      }

      // Verify warning icon is present
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Tap "Understood" action
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Completion Blockers'), findsNothing);
    },
  );
}
