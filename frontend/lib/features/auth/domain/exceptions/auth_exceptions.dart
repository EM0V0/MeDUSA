class MfaRequiredException implements Exception {
  final String tempToken;
  final String message;

  MfaRequiredException({
    required this.tempToken,
    this.message = 'MFA verification required',
  });

  @override
  String toString() => 'MfaRequiredException: $message';
}
