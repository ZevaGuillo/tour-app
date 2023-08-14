import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANONKEY'] ?? '',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  /// Function to generate a random 16 character string.
  String _generateRandomString() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  Future<AuthResponse> signInWithGoogle() async {
    // Just a random string
    final rawNonce = _generateRandomString();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    /// TODO: update the client ID with your own
    ///
    /// Client ID that you registered with Google Cloud.
    /// You will have two different values for iOS and Android.
    final clientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';

    /// reverse DNS form of the client ID + `:/` is set as the redirect URL
    const redirectUrl = 'com.supabase.auth:/google_login';

    /// Fixed value for google login
    const discoveryUrl =
        'https://accounts.google.com/.well-known/openid-configuration';

    final appAuth = FlutterAppAuth();

    // authorize the user by opening the concent page
    final result = await appAuth.authorize(
      AuthorizationRequest(
        clientId,
        redirectUrl,
        discoveryUrl: discoveryUrl,
        nonce: hashedNonce,
        scopes: [
          'openid',
          'email',
        ],
      ),
    );

    if (result == null) {
      throw 'No result';
    }

    // Request the access and id token to google
    final tokenResult = await appAuth.token(
      TokenRequest(
        clientId,
        redirectUrl,
        authorizationCode: result.authorizationCode,
        discoveryUrl: discoveryUrl,
        codeVerifier: result.codeVerifier,
        nonce: result.nonce,
        scopes: [
          'openid',
          'email',
        ],
      ),
    );

    final idToken = tokenResult?.idToken;

    if (idToken == null) {
      throw 'No idToken';
    }

    return supabase.auth.signInWithIdToken(
      provider: Provider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
          child: supabase.auth.currentSession != null
              ? Column(
                  children: [
                    Text(supabase.auth.currentSession.toString()),
                    IconButton(
                        onPressed: () {
                          supabase.auth.signOut();
                        },
                        icon: const Icon(Icons.logout))
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: signInWithGoogle,
                  icon: const SizedBox(
                    height: 36,
                    width: 36,
                  ),
                  label: const Text('Sign in with Google'))),
    );
  }
}
