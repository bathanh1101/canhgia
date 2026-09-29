import 'dart:convert';

import 'package:canhgia_mobile/core/models/profile.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/features/kyc/application/kyc_providers.dart';
import 'package:canhgia_mobile/features/kyc/data/kyc_repository.dart';
import 'package:canhgia_mobile/features/kyc/data/photo.dart';
import 'package:canhgia_mobile/features/kyc/presentation/kyc_screen.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_providers.dart';
import 'package:canhgia_mobile/features/withdraw/data/bank_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final _tinyPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _MockRepo extends Mock implements KycRepository {}

class _FakePicker implements PhotoPicker {
  final photo = PickedPhoto(_tinyPng, 'png', 'image/png');
  @override
  Future<PickedPhoto?> pickOne() async => photo;
  @override
  Future<List<PickedPhoto>> pickMany(int limit) async => [photo];
}

const _banks = [
  Bank(bin: '970436', code: 'VCB', name: 'Vietcombank', isEnabled: true),
  Bank(bin: '999999', code: 'MoMo', name: 'Ví MoMo', isEnabled: false),
];

Widget _app(_MockRepo repo, {KycProfile? profile, List<BankAccount> accounts = const [], bool hasPin = false, int? step}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        kycRepositoryProvider.overrideWithValue(repo),
        photoPickerProvider.overrideWithValue(_FakePicker()),
        kycProfileProvider.overrideWith((ref) async => profile),
        bankAccountsProvider.overrideWith((ref) async => accounts),
        banksProvider.overrideWith((ref) async => _banks),
        profileProvider.overrideWith((ref) async => Profile(id: 'u1', referralCode: 'X', hasPin: hasPin)),
      ],
      child: MaterialApp(home: KycScreen(initialStep: step)),
    );

void main() {
  setUpAll(() => registerFallbackValue(PickedPhoto(_tinyPng, 'png', 'image/png')));

  testWidgets('new user: identity form, submit disabled until complete, then submit_kyc with photos', (t) async {
    final repo = _MockRepo();
    when(() => repo.submit(
          uid: any(named: 'uid'),
          fullName: any(named: 'fullName'),
          idNumber: any(named: 'idNumber'),
          front: any(named: 'front'),
          back: any(named: 'back'),
        )).thenAnswer((_) async {});
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    expect(find.text('1. Định danh'), findsOneWidget);
    FilledButton submit() => t.widget<FilledButton>(find.ancestor(of: find.text('Gửi xác thực'), matching: find.byType(FilledButton)));
    expect(submit().onPressed, isNull);

    await t.enterText(find.byType(TextField).at(0), 'Nguyễn Văn Minh');
    await t.enterText(find.byType(TextField).at(1), '079123456789');
    await t.tap(find.text('Mặt trước'));
    await t.pump();
    await t.tap(find.text('Mặt sau'));
    await t.pump();
    expect(submit().onPressed, isNotNull);

    await t.tap(find.text('Gửi xác thực'));
    await t.pumpAndSettle();
    verify(() => repo.submit(uid: 'u1', fullName: 'Nguyễn Văn Minh', idNumber: '079123456789', front: any(named: 'front'), back: any(named: 'back'))).called(1);
  });

  testWidgets('invalid CCCD length keeps submit disabled', (t) async {
    await t.pumpWidget(_app(_MockRepo()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(0), 'Nguyễn Văn Minh');
    await t.enterText(find.byType(TextField).at(1), '0791234');
    await t.tap(find.text('Mặt trước'));
    await t.pump();
    await t.tap(find.text('Mặt sau'));
    await t.pump();
    final btn = t.widget<FilledButton>(find.ancestor(of: find.text('Gửi xác thực'), matching: find.byType(FilledButton)));
    expect(btn.onPressed, isNull);
  });

  testWidgets('pending review shows "Đang chờ duyệt" and no form', (t) async {
    await t.pumpWidget(_app(_MockRepo(), profile: const KycProfile(status: 'pending', fullName: 'A B', last4: '1234')));
    await t.pumpAndSettle();
    expect(find.text('Đang chờ duyệt'), findsOneWidget);
    expect(find.text('Gửi xác thực'), findsNothing);
  });

  testWidgets('rejected shows the reason and lets the user resubmit', (t) async {
    await t.pumpWidget(_app(_MockRepo(), profile: const KycProfile(status: 'rejected', fullName: 'A B', last4: '1234', rejectReason: 'Ảnh bị mờ')));
    await t.pumpAndSettle();
    expect(find.textContaining('Ảnh bị mờ'), findsOneWidget);
    expect(find.text('Gửi xác thực'), findsOneWidget);
  });

  testWidgets('verified: bank step resumes, name hint follows the CCCD, MoMo disabled', (t) async {
    final repo = _MockRepo();
    when(() => repo.addBank(bankBin: any(named: 'bankBin'), accountNumber: any(named: 'accountNumber'), accountName: any(named: 'accountName')))
        .thenAnswer((_) async => 'id');
    await t.pumpWidget(_app(repo, profile: const KycProfile(status: 'verified', fullName: 'Nguyễn Văn Minh', last4: '4321')));
    await t.pumpAndSettle();
    expect(find.textContaining('✓ CCCD đã xác thực'), findsOneWidget);
    expect(find.text('✓ Khớp CCCD'), findsOneWidget); // prefilled with the normalised CCCD name
    expect(find.text('Sắp có'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(1), 'NGUYEN VAN AN');
    await t.pump();
    expect(find.text('Chưa khớp CCCD'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(1), 'NGUYEN VAN MINH');
    await t.enterText(find.byType(TextField).at(0), '0071 0012 3456 789');
    await t.tap(find.text('Vietcombank'));
    await t.pump();
    await t.ensureVisible(find.text('Tiếp tục · Tạo mã PIN'));
    await t.pump();
    await t.tap(find.text('Tiếp tục · Tạo mã PIN'));
    await t.pumpAndSettle();
    verify(() => repo.addBank(bankBin: '970436', accountNumber: '007100123456789', accountName: 'NGUYEN VAN MINH')).called(1);
  });

  testWidgets('verified + bank linked, no PIN: step 3 offers PIN creation; step param cannot skip ahead', (t) async {
    const bank = BankAccount(id: 'b', bankBin: '970436', accountNumber: '0071001234', accountName: 'A', isDefault: true);
    await t.pumpWidget(_app(_MockRepo(), profile: const KycProfile(status: 'verified', fullName: 'A B', last4: '1'), accounts: [bank]));
    await t.pumpAndSettle();
    expect(find.text('Tạo mã PIN rút tiền'), findsOneWidget);

    await t.pumpWidget(_app(_MockRepo(), step: 3)); // nothing done yet -> clamped to step 1
    await t.pumpAndSettle();
    expect(find.text('Gửi xác thực'), findsOneWidget);
  });
}
