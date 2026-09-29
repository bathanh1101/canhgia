import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:canhgia_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('J3: Withdraw with PIN', () {
    testWidgets('set PIN → verify_pin → withdraw flow', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Login
      final loginBtn = find.byType(ElevatedButton).first;
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Navigate to account/settings to set PIN
      final accountTab = find.text('Account');
      await tester.tap(accountTab);
      await tester.pumpAndSettle();

      if (find.text('Set PIN').evaluate().isNotEmpty) {
        await tester.tap(find.text('Set PIN'));
        await tester.pumpAndSettle();

        // Enter PIN (6 digits)
        for (var i = 0; i < 6; i++) {
          await tester.enterText(find.byType(TextField).at(i), '1');
        }
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.byType(ElevatedButton).first);
        await tester.pumpAndSettle();
      }

      // Navigate to withdraw
      final walletTab = find.text('Wallet');
      await tester.tap(walletTab);
      await tester.pumpAndSettle();

      final withdrawBtn = find.text('Withdraw');
      if (withdrawBtn.evaluate().isNotEmpty) {
        await tester.tap(withdrawBtn);
        await tester.pumpAndSettle();

        // Enter amount
        await tester.enterText(find.byType(TextField).first, '100000');
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.byType(ElevatedButton).first);
        await tester.pumpAndSettle();

        // Enter PIN to verify
        for (var i = 0; i < 6; i++) {
          await tester.enterText(find.byType(TextField).at(i), '1');
        }
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ElevatedButton).first);
        await tester.pumpAndSettle();

        // Verify success
        expect(find.byType(SnackBar), findsWidgets);
      }
    });

    testWidgets('wrong PIN 6 times locks account', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Navigate to withdraw (assumes already set up)
      final withdrawBtn = find.text('Withdraw');
      if (withdrawBtn.evaluate().isNotEmpty) {
        await tester.tap(withdrawBtn);
        await tester.pumpAndSettle();

        // Try wrong PIN 6 times
        for (int attempt = 0; attempt < 6; attempt++) {
          // Enter amount
          await tester.enterText(find.byType(TextField).first, '50000');
          await tester.pumpAndSettle();

          await tester.tap(find.byType(ElevatedButton).first);
          await tester.pumpAndSettle();

          // Enter wrong PIN
          for (var i = 0; i < 6; i++) {
            await tester.enterText(find.byType(TextField).at(i), '0');
          }
          await tester.pumpAndSettle();

          await tester.tap(find.byType(ElevatedButton).first);
          await tester.pumpAndSettle();
        }

        // After 6 attempts, should show locked message
        final lockedMsg = find.byWidgetPredicate(
          (w) => w is Text && w.data?.contains('locked|Bị khóa') == true,
        );
        expect(lockedMsg, findsWidgets);
      }
    });

    testWidgets('new bank account triggers hold', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Navigate to account
      final accountTab = find.text('Account');
      await tester.tap(accountTab);
      await tester.pumpAndSettle();

      final bankBtn = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.child is Text && (w.child as Text).data?.contains('Bank') == true,
      );
      if (find.text('Bank Accounts').evaluate().isNotEmpty) {
        await tester.tap(find.text('Bank Accounts'));
        await tester.pumpAndSettle();

        // Add new account
        final addBtn = find.byType(FloatingActionButton);
        if (addBtn.evaluate().isNotEmpty) {
          await tester.tap(addBtn);
          await tester.pumpAndSettle();

          // Fill bank info
          await tester.enterText(find.byType(TextField).at(0), '1234567890');
          await tester.enterText(find.byType(TextField).at(1), 'Test Bank');
          await tester.pumpAndSettle();

          await tester.tap(find.byType(ElevatedButton).first);
          await tester.pumpAndSettle();

          // Try to withdraw - should show hold_active error
          final holdMsg = find.byWidgetPredicate(
            (w) => w is Text && w.data?.contains('unverified|hold_active') == true,
          );
          expect(holdMsg, findsWidgets);
        }
      }
    });
  });
}
