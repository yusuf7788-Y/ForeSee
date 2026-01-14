import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_screen_wrapper.dart';
import '../../widgets/grey_notification.dart';

class OtpScreen extends StatefulWidget {
  final OtpSessionPayload payload;

  const OtpScreen({super.key, required this.payload});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _pinController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isVerifying = false;
  int _secondsLeft = 45;
  Timer? _timer;
  String? _error;
  late OtpSessionPayload _currentPayload;

  @override
  void initState() {
    super.initState();
    _currentPayload = widget.payload;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsLeft -= 1;
        });
      }
    });
  }

  Future<void> _resendCode() async {
    try {
      final otpResult = await _authService.startEmailFlow(
        email: _currentPayload.email,
        flow: _currentPayload.flow,
        name: _currentPayload.name,
      );
      if (!mounted) return;
      setState(() {
        _currentPayload = OtpSessionPayload(
          email: _currentPayload.email,
          name: _currentPayload.name,
          flow: _currentPayload.flow,
          sessionId: otpResult.sessionId,
          isMock: otpResult.isMock,
        );
        _error = null;
      });
      _pinController.clear();
      _startTimer();
      GreyNotification.show(context, 'Kod yeniden gönderildi');
    } catch (e) {
      GreyNotification.show(context, e.toString());
    }
  }

  Future<void> _verify() async {
    if (_pinController.text.length != 5) {
      setState(() => _error = '5 haneli kodu girin');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await _authService.verifyOtpAndSignIn(
        email: _currentPayload.email,
        code: _pinController.text.trim(),
        flow: _currentPayload.flow,
        sessionId: _currentPayload.sessionId,
        name: _currentPayload.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kod doğru değil';
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentPayload.email;
    return AuthScreenWrapper(
      headline: 'Son bir adım kaldı',
      subtitle:
          '$email adresine 5 haneli doğrulama kodu gönderdik, lütfen kodu gir.',
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        children: [
          Pinput(
            length: 5,
            controller: _pinController,
            autofocus: true,
            onCompleted: (_) => _verify(),
            defaultPinTheme: PinTheme(
              height: 60,
              width: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF111111)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: Theme.of(context).brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              textStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isVerifying ? null : _verify,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: _isVerifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: _secondsLeft == 0 ? _resendCode : null,
            icon: Icon(
              Icons.refresh,
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacity(0.7),
              size: 18,
            ),
            label: Text(
              _secondsLeft == 0
                  ? 'Tekrar kod gönder'
                  : 'Tekrar gönder (${_secondsLeft}s)',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
