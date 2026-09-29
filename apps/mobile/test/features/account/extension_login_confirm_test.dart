import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/account/application/account_providers.dart';
import 'package:canhgia_mobile/features/account/data/account_repository.dart';
import 'package:canhgia_mobile/features/account/presentation/extension_login_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AccountRepository {}

const _code = '3f2b8c1e-9d4a-4b6e-8f10-2a7c5d9e0b13';
const _ua = 'Mozilla/5.0 (Windows NT 10.0) Chrome/126.0 Safari/537.36';

Widget _app(_MockRepo repo, String? code) => ProviderScope(
      overrides: [accountRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: ExtensionLoginConfirmScreen(code: code)),
    );

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  testWidgets('shows device summary and approves only after the button is tapped', (t) async {
    when(() => repo.getExtensionLoginRequest(_code)).thenAnswer((_) async => ExtensionLoginRequest(
          userAgent: _ua,
          ipMasked: '1.2.3.x',
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ));
    when(() => repo.approveExtensionLogin(_code)).thenAnswer((_) async {});

    await t.pumpWidget(_app(repo, _code));
    await t.pump();
    expect(find.text('Chrome trên Windows'), findsOneWidget);
    expect(find.textContaining('IP 1.2.3.x'), findsOneWidget);
    expect(find.textContaining('Chỉ xác nhận nếu chính bạn'), findsOneWidget);
    verifyNever(() => repo.approveExtensionLogin(any()));

    await t.tap(find.text('Xác nhận đăng nhập'));
    await t.pump();
    verify(() => repo.approveExtensionLogin(_code)).called(1);
    expect(find.text('Đã đăng nhập tiện ích'), findsOneWidget);
  });

  testWidgets('expired code from the server shows the regenerate hint', (t) async {
    when(() => repo.getExtensionLoginRequest(_code)).thenThrow(PostgrestException(message: 'code_invalid'));
    await t.pumpWidget(_app(repo, _code));
    await t.pump();
    expect(find.text('Mã hết hạn, tạo mã mới trên tiện ích.'), findsOneWidget);
    expect(find.text('Xác nhận đăng nhập'), findsNothing);
  });

  testWidgets('approve failing with code_invalid shows the hint, no success state', (t) async {
    when(() => repo.getExtensionLoginRequest(_code)).thenAnswer((_) async => ExtensionLoginRequest(
        userAgent: _ua, ipMasked: '1.2.3.x', expiresAt: DateTime.now().add(const Duration(minutes: 1))));
    when(() => repo.approveExtensionLogin(_code)).thenThrow(PostgrestException(message: 'code_invalid'));
    await t.pumpWidget(_app(repo, _code));
    await t.pump();
    await t.tap(find.text('Xác nhận đăng nhập'));
    await t.pump();
    expect(find.text('Mã hết hạn, tạo mã mới trên tiện ích.'), findsOneWidget);
    expect(find.text('Đã đăng nhập tiện ích'), findsNothing);
  });

  testWidgets('malformed code never reaches the backend', (t) async {
    await t.pumpWidget(_app(repo, 'garbage'));
    await t.pump();
    expect(find.text(errorMessagesVi['code_invalid']!), findsOneWidget);
    verifyZeroInteractions(repo);
  });
}
