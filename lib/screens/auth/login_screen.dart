import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_screen_wrapper.dart';
import '../../widgets/grey_notification.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AuthFlow flow) onSwitchFlow;
  final void Function(OtpSessionPayload payload) onOtpRequested;
  final VoidCallback onGooglePressed;
  final bool isProcessingGoogle;

  const LoginScreen({
    super.key,
    required this.onSwitchFlow,
    required this.onOtpRequested,
    required this.onGooglePressed,
    this.isProcessingGoogle = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService.instance;

  EmailValidationState _emailState = EmailValidationState.empty;
  String? _emailMessage;
  Timer? _debounce;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmail);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _handleEmail() {
    final value = _emailController.text.trim();
    _debounce?.cancel();

    if (value.isEmpty) {
      setState(() {
        _emailState = EmailValidationState.empty;
        _emailMessage = null;
      });
      return;
    }

    if (!value.contains('@')) {
      setState(() {
        _emailState = EmailValidationState.invalid;
        _emailMessage = '@ işaretini unutmayın';
      });
      return;
    }

    setState(() {
      _emailState = EmailValidationState.typing;
      _emailMessage = null;
    });

    _debounce = Timer(const Duration(milliseconds: 700), () async {
      setState(() => _emailState = EmailValidationState.checking);
      final result = await _authService.checkEmailForLogin(value);
      if (!mounted) return;
      setState(() {
        _emailState = result.state;
        _emailMessage = result.message;
      });
    });
  }

  bool get _canSubmit =>
      _emailState == EmailValidationState.available && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      final otpResult = await _authService.startEmailFlow(
        email: email,
        flow: AuthFlow.login,
      );
      if (!mounted) return;
      widget.onOtpRequested(
        OtpSessionPayload(
          email: email,
          flow: AuthFlow.login,
          sessionId: otpResult.sessionId,
          isMock: otpResult.isMock,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenWrapper(
      headline: 'Tekrar hoş geldin',
      subtitle: 'Hesabına erişmek için e-postanı doğrula',
      showText: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildInput(
              label: 'E-posta',
              controller: _emailController,
              suffix: _buildEmailSuffix(),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          if (_emailMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _emailMessage!,
                style: TextStyle(
                  color: _emailState == EmailValidationState.available
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Devam Et',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => widget.onSwitchFlow(AuthFlow.register),
            child: Text.rich(
              TextSpan(
                text: 'Kayıtlı hesabın yok mu? ',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.8),
                  fontSize: 12,
                ),
                children: const [
                  TextSpan(
                    text: 'Kayıt ol',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ElevatedButton.icon(
              onPressed: widget.isProcessingGoogle
                  ? null
                  : widget.onGooglePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              icon: widget.isProcessingGoogle
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Image.asset('assets/google_logo.png', height: 18),
              label: const Text(
                'Google ile devam et',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          fontSize: 12,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        suffixIcon: suffix,
      ),
    );
  }

  Widget? _buildEmailSuffix() {
    switch (_emailState) {
      case EmailValidationState.checking:
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case EmailValidationState.notFound:
      case EmailValidationState.invalid:
      case EmailValidationState.error:
        return const Icon(Icons.cancel, color: Colors.redAccent);
      case EmailValidationState.available:
        return const Icon(Icons.check_circle, color: Colors.greenAccent);
      default:
        return null;
    }
  }
}
