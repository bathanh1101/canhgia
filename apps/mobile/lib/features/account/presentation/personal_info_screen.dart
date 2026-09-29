import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../application/account_providers.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _name = TextEditingController();
  var _seeded = false;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty || name.length > 60) {
      messenger.showSnackBar(const SnackBar(content: Text('Tên hiển thị cần từ 1 đến 60 ký tự.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(displayName: name);
      if (mounted) ref.invalidate(profileProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu thông tin.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    if (!_seeded && profile != null) {
      _name.text = profile.displayName ?? '';
      _seeded = true;
    }
    return Scaffold(
      appBar: const AppTopBar(title: 'Thông tin cá nhân'),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(labelText: 'Tên hiển thị')),
        const SizedBox(height: 8),
        TextFormField(
          enabled: false,
          initialValue: profile?.email ?? '',
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          enabled: false,
          initialValue: profile?.referralCode ?? '',
          decoration: const InputDecoration(labelText: 'Mã giới thiệu'),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Lưu', loading: _saving, onPressed: _save),
      ]),
    );
  }
}
