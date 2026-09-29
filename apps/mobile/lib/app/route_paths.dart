/// Single source of route paths for all screens. Features navigate with these,
/// never with string literals.
class RoutePaths {
  const RoutePaths._();

  // auth / onboarding
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const loginEmailOtp = '/login/email-otp';

  // shell tabs
  static const home = '/home';
  static const vouchers = '/vouchers';
  static const wallet = '/wallet';
  static const rewards = '/rewards';
  static const account = '/account';

  // account sub-pages
  static const accountInfo = '/account/info';
  static const accountDevices = '/account/devices';
  static const accountNotificationSettings = '/account/notification-settings';
  static const accountExtensionLogin = '/account/extension-login';
  static const accountExtensionConfirm = '/account/extension-login/confirm'; // ?code=<uuid>

  // shopping (05)
  static const link = '/link/:clickId'; // extra: CreatedLink
  static String linkFor(String clickId) => '/link/${Uri.encodeComponent(clickId)}';
  static const search = '/search';
  static const searchResults = '/search/results'; // ?q=&m=&sort=
  static const compare = '/compare/:groupId';
  static String compareFor(String groupId) => '/compare/${Uri.encodeComponent(groupId)}';
  static const priceHistory = '/price-history/:groupId';
  static String priceHistoryFor(String groupId) => '/price-history/${Uri.encodeComponent(groupId)}';
  static const watchlist = '/watchlist';

  // wallet (06)
  static const orderDetail = '/orders/:id';
  static String orderDetailFor(String id) => '/orders/${Uri.encodeComponent(id)}';
  static const withdraw = '/withdraw';
  static const pin = '/pin'; // ?mode=verify|create|change|reset
  static String pinFor(String mode) => '/pin?mode=$mode';

  /// Verify the PIN and pop the verified 6-digit PIN string as the route result
  /// (`final pin = await context.push<String>(RoutePaths.pinVerifyReturnPin)`).
  /// Used by the account biometric toggle; no `pin_token` is issued for this call.
  static const pinVerifyReturnPin = '/pin?mode=verify&return=pin';
  static const missingOrder = '/missing-order';
  static const kyc = '/kyc'; // ?step=1|2|3
  static String kycStep(int step) => '/kyc?step=$step';
  static const notifications = '/notifications';

  /// Deep link `<APP_BASE_URL>/r/<code>` -> stored for bind_referral after login.
  static const referralPrefix = '/r/';
}
