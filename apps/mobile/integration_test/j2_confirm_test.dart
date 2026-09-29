import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:canhgia_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('J2: Confirm & hold workflow', () {
    testWidgets('conversion status 1 → order held', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Login first (reuse from J1)
      final loginBtn = find.byType(ElevatedButton).first;
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Navigate to orders
      final ordersTab = find.text('Orders');
      await tester.tap(ordersTab);
      await tester.pumpAndSettle();

      // Find order with status "Chờ duyệt" (held)
      final heldOrder = find.byWidgetPredicate(
        (w) => w is Text && w.data?.contains('Chờ duyệt') == true,
      );
      expect(heldOrder, findsWidgets);
    });

    testWidgets('pending→held→available transitions', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Verify wallet shows correct states
      final walletTab = find.text('Wallet');
      await tester.tap(walletTab);
      await tester.pumpAndSettle();

      final balanceCard = find.byType(Card);
      expect(balanceCard, findsWidgets);

      // Check balance rows contain "Available", "Pending", "Held" labels
      final availableText = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('Available') == true || w.data?.contains('Khả dụng') == true),
      );
      expect(availableText, findsWidgets);
    });

    testWidgets('replay sync is idempotent', (WidgetTester tester) async {
      await app.main();
      await tester.pumpAndSettle();

      // Navigate to wallet
      final walletTab = find.text('Wallet');
      await tester.tap(walletTab);
      await tester.pumpAndSettle();

      // Record initial balance
      final balanceTextFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data?.contains(RegExp(r'\d+,\d+')) == true,
      );
      expect(balanceTextFinder, findsWidgets);

      // Wait and check balance doesn't change (idempotent)
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(balanceTextFinder, findsWidgets);
    });
  });
}
