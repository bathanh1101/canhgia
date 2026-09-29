import 'dart:convert';
import 'dart:math';

// crypto is a transitive dependency (pubspec is frozen for this phase).
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';

typedef GoogleTokens = ({String idToken, String? accessToken});

/// Auth calls only; navigation happens through the router's session redirect.
class AuthRepository {
  AuthRepository(this._auth, {Future<GoogleTokens?> Function(String hashedNonce)? googleTokens})
      : _googleTokens = googleTokens ?? _nativeGoogleTokens;

  final GoTrueClient _auth;
  final Future<GoogleTokens?> Function(String hashedNonce) _googleTokens;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _otp = RegExp(r'^\d{6}$');

  /// Native Google -> `signInWithIdToken`. Returns false when the user cancelled.
  Future<bool> signInWithGoogle() async {
    if (!Env.googleConfigured) throw const AppFailure('google_not_configured');
    // Google embeds sha256(raw) in the id token; GoTrue re-hashes the raw value we pass.
    final raw = generateRawNonce();
    final tokens = await _googleTokens(hashNonce(raw));
    if (tokens == null) return false;
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
      nonce: raw,
    );
    return true;
  }

  /// Sends a 6-digit code. [captchaToken] is null when Turnstile is not configured.
  Future<void> sendEmailOtp(String email, {String? captchaToken}) {
    final e = email.trim();
    if (!_email.hasMatch(e)) throw const AppFailure('invalid_input');
    return _auth.signInWithOtp(email: e, shouldCreateUser: true, captchaToken: captchaToken);
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    final c = code.trim();
    if (!_otp.hasMatch(c)) throw const AppFailure('invalid_input');
    await _auth.verifyOTP(email: email.trim(), token: c, type: OtpType.email);
  }

  Future<void> signOut() => _auth.signOut();
}

/// 32 random bytes as hex.
String generateRawNonce([Random? rng]) {
  final r = rng ?? Random.secure();
  return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String hashNonce(String raw) => sha256.convert(utf8.encode(raw)).toString();

// initialize() is per attempt because the nonce is bound at init time.
Future<GoogleTokens?> _nativeGoogleTokens(String hashedNonce) async {
  final g = GoogleSignIn.instance;
  await g.initialize(
    nonce: hashedNonce,
    clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
    serverClientId: Env.googleWebClientId,
  );
  try {
    final account = await g.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AppFailure('unknown');
    final authz = await account.authorizationClient.authorizationForScopes(['email']);
    return (idToken: idToken, accessToken: authz?.accessToken);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    rethrow;
  }
}
