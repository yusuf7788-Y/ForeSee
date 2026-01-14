import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/grey_notification.dart';
import 'login_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  AuthFlow _currentFlow = AuthFlow.register;
  bool _isProcessing = false;

  final AuthService _authService = AuthService.instance;

  void _switchFlow(AuthFlow flow) {
    if (_currentFlow == flow) return;
    setState(() {
      _currentFlow = flow;
    });
  }

  Future<void> _openOtp(OtpSessionPayload payload) async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpScreen(payload: payload),
      ),
    );

    if (result == true && mounted) {
      GreyNotification.show(context, 'Başarıyla doğrulandı');
    }
  }

  Future<void> _handleGoogle(AuthFlow flow) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _authService.signInWithGoogle(flow);
    } catch (e) {
      if (!mounted) return;
      GreyNotification.show(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentFlow == AuthFlow.login) {
      return LoginScreen(
        onSwitchFlow: _switchFlow,
        onOtpRequested: _openOtp,
        onGooglePressed: () => _handleGoogle(AuthFlow.login),
        isProcessingGoogle: _isProcessing,
      );
    }
    return RegisterScreen(
      onSwitchFlow: _switchFlow,
      onOtpRequested: _openOtp,
      onGooglePressed: () => _handleGoogle(AuthFlow.register),
      isProcessingGoogle: _isProcessing,
    );
  }
}

