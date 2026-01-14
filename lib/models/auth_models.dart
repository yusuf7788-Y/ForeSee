enum AuthFlow {
  register,
  login,
}

enum EmailValidationState {
  empty,
  typing,
  invalid,
  checking,
  available,
  exists,
  notFound,
  error,
}

class OtpSessionPayload {
  final String email;
  final String? name;
  final AuthFlow flow;
  final String sessionId;
  final bool isMock;

  const OtpSessionPayload({
    required this.email,
    required this.flow,
    required this.sessionId,
    this.name,
    this.isMock = false,
  });
}

class EmailCheckResult {
  final EmailValidationState state;
  final String? message;

  const EmailCheckResult({
    required this.state,
    this.message,
  });
}

class OtpRequestResult {
  final String sessionId;
  final bool isMock;
  final Duration validFor;

  const OtpRequestResult({
    required this.sessionId,
    this.isMock = false,
    this.validFor = const Duration(minutes: 5),
  });
}

class OtpVerifyResult {
  final String? customToken;
  final String? profileName;

  const OtpVerifyResult({
    this.customToken,
    this.profileName,
  });
}

