import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

/// OAuth authentication service for third-party login providers
/// Supports Google Sign-In, Apple Sign-In, and custom OAuth providers
class OAuthService extends ChangeNotifier {
  static final OAuthService _instance = OAuthService._internal();
  factory OAuthService() => _instance;
  OAuthService._internal();

  // Google Sign-In configuration
  static const List<String> _googleScopes = [
    'email',
    'profile',
  ];

  late GoogleSignIn _googleSignIn;
  
  // OAuth state
  GoogleSignInAccount? _googleUser;
  Map<String, dynamic>? _appleUser;
  bool _isSigningIn = false;
  String? _lastError;

  // Getters
  GoogleSignInAccount? get googleUser => _googleUser;
  Map<String, dynamic>? get appleUser => _appleUser;
  bool get isSigningIn => _isSigningIn;
  String? get lastError => _lastError;
  bool get isGoogleSignedIn => _googleUser != null;
  bool get isAppleSignedIn => _appleUser != null;
  bool get isSignedIn => isGoogleSignedIn || isAppleSignedIn;

  /// Initialize OAuth service
  Future<void> initialize() async {
    try {
      // Initialize Google Sign-In with web-specific configuration
      _googleSignIn = GoogleSignIn(
        scopes: _googleScopes,
        signInOption: SignInOption.standard,
      );

      // Check for existing Google sign-in
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _googleUser = account;
        notifyListeners();
      }

      debugPrint('OAuth service initialized');
    } catch (e) {
      _setError('Failed to initialize OAuth service: $e');
    }
  }

  /// Sign in with Google
  Future<OAuthResult> signInWithGoogle() async {
    if (_isSigningIn) {
      return OAuthResult.error('Sign-in already in progress');
    }

    try {
      _setSigningIn(true);
      _clearError();

      // Attempt to sign in
      final account = await _googleSignIn.signIn();
      
      if (account == null) {
        // User cancelled the sign-in
        return OAuthResult.cancelled('Google sign-in cancelled by user');
      }

      // Get authentication details
      final authentication = await account.authentication;
      
      if (authentication.accessToken == null) {
        throw Exception('Failed to get access token');
      }

      _googleUser = account;
      notifyListeners();

      return OAuthResult.success(
        provider: 'google',
        user: {
          'id': account.id,
          'email': account.email,
          'displayName': account.displayName,
          'photoUrl': account.photoUrl,
          'accessToken': authentication.accessToken,
          'idToken': authentication.idToken,
        },
      );
    } catch (e) {
      _setError('Google sign-in failed: $e');
      return OAuthResult.error('Google sign-in failed: $e');
    } finally {
      _setSigningIn(false);
    }
  }

  /// Sign in with Apple
  Future<OAuthResult> signInWithApple() async {
    if (_isSigningIn) {
      return OAuthResult.error('Sign-in already in progress');
    }

    // Check if Apple Sign-In is available
    if (!await SignInWithApple.isAvailable()) {
      return OAuthResult.error('Apple Sign-In is not available on this device');
    }

    try {
      _setSigningIn(true);
      _clearError();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'your.app.bundle.id', // Replace with your actual client ID
          redirectUri: Uri.parse('https://your-app.com/auth/apple/callback'),
        ),
      );

      final user = {
        'id': credential.userIdentifier,
        'email': credential.email,
        'givenName': credential.givenName,
        'familyName': credential.familyName,
        'identityToken': credential.identityToken,
        'authorizationCode': credential.authorizationCode,
      };

      _appleUser = user;
      notifyListeners();

      return OAuthResult.success(
        provider: 'apple',
        user: user,
      );
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          return OAuthResult.cancelled('Apple sign-in cancelled by user');
        }
      }
      
      _setError('Apple sign-in failed: $e');
      return OAuthResult.error('Apple sign-in failed: $e');
    } finally {
      _setSigningIn(false);
    }
  }

  /// Sign in with Microsoft (custom OAuth flow)
  Future<OAuthResult> signInWithMicrosoft() async {
    if (_isSigningIn) {
      return OAuthResult.error('Sign-in already in progress');
    }

    try {
      _setSigningIn(true);
      _clearError();

      // Microsoft OAuth 2.0 endpoints
      const String clientId = 'your-microsoft-client-id'; // Replace with actual client ID
      const String redirectUri = 'https://your-app.com/auth/microsoft/callback';
      const String scope = 'openid profile email';
      
      final authUrl = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scope,
        'response_mode': 'query',
        'state': _generateState(),
      });

      // Launch browser for authentication with web-specific mode
      LaunchMode launchMode = kIsWeb 
          ? LaunchMode.inAppWebView // Use in-app web view for web to prevent overflow
          : LaunchMode.externalApplication;
      
      if (await canLaunchUrl(authUrl)) {
        if (kIsWeb) {
          await launchUrl(
            authUrl, 
            mode: launchMode,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        } else {
          await launchUrl(authUrl, mode: launchMode);
        }
        
        // In a real implementation, you would:
        // 1. Handle the redirect URI callback
        // 2. Extract the authorization code
        // 3. Exchange it for access token
        // 4. Get user info from Microsoft Graph API
        
        // For demo purposes, return a placeholder result
        return OAuthResult.success(
          provider: 'microsoft',
          user: {
            'id': 'demo-microsoft-user',
            'email': 'user@outlook.com',
            'displayName': 'Microsoft User',
          },
        );
      } else {
        throw Exception('Could not launch Microsoft authentication URL');
      }
    } catch (e) {
      _setError('Microsoft sign-in failed: $e');
      return OAuthResult.error('Microsoft sign-in failed: $e');
    } finally {
      _setSigningIn(false);
    }
  }

  /// Sign out from all providers
  Future<void> signOut() async {
    try {
      // Sign out from Google
      if (_googleUser != null) {
        await _googleSignIn.signOut();
        _googleUser = null;
      }

      // Clear Apple user data
      if (_appleUser != null) {
        _appleUser = null;
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Sign-out failed: $e');
    }
  }

  /// Disconnect from Google (revoke access)
  Future<void> disconnectGoogle() async {
    try {
      if (_googleUser != null) {
        await _googleSignIn.disconnect();
        _googleUser = null;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to disconnect from Google: $e');
    }
  }

  /// Get current user information
  Map<String, dynamic>? getCurrentUser() {
    if (_googleUser != null) {
      return {
        'provider': 'google',
        'id': _googleUser!.id,
        'email': _googleUser!.email,
        'displayName': _googleUser!.displayName,
        'photoUrl': _googleUser!.photoUrl,
      };
    } else if (_appleUser != null) {
      return {
        'provider': 'apple',
        ..._appleUser!,
      };
    }
    return null;
  }

  /// Check if a specific provider is available
  Future<bool> isProviderAvailable(String provider) async {
    switch (provider.toLowerCase()) {
      case 'google':
        return true; // Google Sign-In is available on all platforms
      case 'apple':
        return await SignInWithApple.isAvailable();
      case 'microsoft':
        return true; // Custom OAuth flow, available on all platforms
      default:
        return false;
    }
  }

  /// Get available OAuth providers
  Future<List<String>> getAvailableProviders() async {
    final providers = <String>[];
    
    if (await isProviderAvailable('google')) {
      providers.add('google');
    }
    
    if (await isProviderAvailable('apple')) {
      providers.add('apple');
    }
    
    if (await isProviderAvailable('microsoft')) {
      providers.add('microsoft');
    }
    
    return providers;
  }

  /// Generate state parameter for OAuth
  String _generateState() {
    final bytes = List<int>.generate(32, (i) => 
        DateTime.now().millisecondsSinceEpoch.hashCode + i);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Set signing in state
  void _setSigningIn(bool signing) {
    _isSigningIn = signing;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _lastError = error;
    debugPrint('OAuth Error: $error');
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Get OAuth service status
  Map<String, dynamic> getStatus() {
    return {
      'isSignedIn': isSignedIn,
      'isGoogleSignedIn': isGoogleSignedIn,
      'isAppleSignedIn': isAppleSignedIn,
      'isSigningIn': _isSigningIn,
      'currentUser': getCurrentUser(),
      'lastError': _lastError,
    };
  }

  /// Dispose service
  @override
  void dispose() {
    super.dispose();
  }
}

/// OAuth authentication result
class OAuthResult {
  final bool success;
  final String? provider;
  final Map<String, dynamic>? user;
  final String? error;
  final bool cancelled;

  OAuthResult._({
    required this.success,
    this.provider,
    this.user,
    this.error,
    this.cancelled = false,
  });

  factory OAuthResult.success({
    required String provider,
    required Map<String, dynamic> user,
  }) {
    return OAuthResult._(
      success: true,
      provider: provider,
      user: user,
    );
  }

  factory OAuthResult.error(String error) {
    return OAuthResult._(
      success: false,
      error: error,
    );
  }

  factory OAuthResult.cancelled(String message) {
    return OAuthResult._(
      success: false,
      error: message,
      cancelled: true,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'OAuthResult.success(provider: $provider, user: ${user?['email']})';
    } else if (cancelled) {
      return 'OAuthResult.cancelled($error)';
    } else {
      return 'OAuthResult.error($error)';
    }
  }
}
