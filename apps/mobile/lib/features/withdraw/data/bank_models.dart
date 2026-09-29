/// Row of `banks` (public reference list). E-wallets ship disabled (`is_enabled=false`).
class Bank {
  const Bank({required this.bin, required this.code, required this.name, required this.isEnabled});

  static const columns = 'bin,code,name,is_enabled,sort';

  final String bin;
  final String code;
  final String name;
  final bool isEnabled;

  factory Bank.fromJson(Map<String, dynamic> j) => Bank(
        bin: j['bin'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        isEnabled: j['is_enabled'] as bool? ?? true,
      );
}

/// Row of `bank_accounts` (own rows).
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    required this.isDefault,
    this.holderNameVerified = false,
  });

  static const columns = 'id,bank_bin,account_number,account_name,is_default,holder_name_verified,created_at';

  final String id;
  final String bankBin;
  final String accountNumber;
  final String accountName;
  final bool isDefault;
  final bool holderNameVerified;

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['id'] as String,
        bankBin: j['bank_bin'] as String,
        accountNumber: j['account_number'] as String,
        accountName: j['account_name'] as String,
        isDefault: j['is_default'] as bool? ?? false,
        holderNameVerified: j['holder_name_verified'] as bool? ?? false,
      );

  /// "•••• 6789".
  String get masked => '•••• ${accountNumber.length <= 4 ? accountNumber : accountNumber.substring(accountNumber.length - 4)}';
}

/// Picks the default account, else the first one.
BankAccount? pickDefaultAccount(List<BankAccount> all) =>
    all.where((a) => a.isDefault).firstOrNull ?? all.firstOrNull;
