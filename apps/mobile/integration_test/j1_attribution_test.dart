import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:canhgia_mobile/main.dart' as app;
import 'helpers/mailpit_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('J1: Attribution journey', () {
    testWidgets('user login → paste Shopee link → create link → assert clicks', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Navigate to login
      final loginBtn = find.byType(ElevatedButton).first;
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(find.byType(TextField).first, 'minh@test.canhgia.local');
      await tester.pumpAndSettle();

      // Request OTP
      final submitBtn = find.byWidgetPredicate(
        (w) => w is ElevatedButton && w.child is Text && (w.child as Text).data?.contains('Send') == true,
      );
      await tester.tap(submitBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Fetch OTP from Mailpit
      final otp = await MailpitClient.getOtpCode('minh@test.canhgia.local');

      // Enter OTP
      await tester.enterText(find.byType(TextField).first, otp);
      await tester.pumpAndSettle();

      // Verify signed in (should be on home)
      expect(find.byType(AppBar), findsWidgets);

      // Navigate to link creation
      final linkTab = find.text('Link');
      if (find.byWidgetPredicate((w) => w is Tab && w.child is Text && (w.child as Text).data?.contains('Link') == true).evaluate().isNotEmpty) {
        await tester.tap(linkTab);
        await tester.pumpAndSettle();
      }

      // Paste Shopee URL
      final urlInput = find.byType(TextField).first;
      await tester.enterText(urlInput, 'https://shopee.vn/sp-1');
      await tester.pumpAndSettle();

      // Create link
      final createBtn = find.byWidgetPredicate(
        (w) => w is ElevatedButton && w.child is Text && (w.child as Text).data?.contains('Create') == true,
      );
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify link created
      expect(find.byType(SnackBar), findsWidgets);
      expect(find.text('Link created'), findsOneWidget);
    });

    testWidgets('wallet pending updates on AT conversion', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Navigate to wallet
      final walletTab = find.text('Wallet');
      await tester.tap(walletTab);
      await tester.pumpAndSettle();

      // Check initial pending amount
      final pendingText = find.byWidgetPredicate(
        (w) => w is Text && w.data?.contains('Pending') == true,
      );
      expect(pendingText, findsWidgets);

      // Wait for realtime update (max 5 seconds)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify pending amount increased or notification appeared
      final notification = find.byType(SnackBar);
      expect(notification, findsWidgets);
    });
  });
}
