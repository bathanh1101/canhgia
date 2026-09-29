import '../../../core/utils/vn_text.dart';
import '../data/kyc_repository.dart';

/// CCCD (12) or CMND (9) digits, same shape as `submit_kyc`.
bool isValidIdNumber(String v) => RegExp(r'^(\d{9}|\d{12})$').hasMatch(v);

/// 6-19 digits, same shape as `add_bank_account` (spaces allowed while typing).
bool isValidAccountNumber(String v) => RegExp(r'^\d{6,19}$').hasMatch(v.replaceAll(RegExp(r'\s'), ''));

/// Live hint "✓ Khớp CCCD": server compares the same normalised form.
bool nameMatchesCccd(String accountName, String cccdName) =>
    accountName.trim().isNotEmpty && normalizeName(accountName) == normalizeName(cccdName);

/// First step the user still has to do: 1 identity, 2 bank, 3 PIN (3 also = "done" when [hasPin]).
int kycResumeStep({required KycProfile? profile, required int bankAccounts, required bool hasPin}) {
  if (profile == null || !profile.isVerified) return 1;
  if (bankAccounts == 0) return 2;
  return 3;
}
