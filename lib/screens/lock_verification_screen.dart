import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../models/lock_type.dart';
import '../services/security_service.dart';
import '../widgets/pattern_lock.dart';

class LockVerificationScreen extends StatefulWidget {
  final LockType lockType;
  final String? lockData;
  final String title;

  const LockVerificationScreen({
    super.key,
    required this.lockType,
    required this.lockData,
    this.title = 'Kilidi Açın',
  });

  @override
  State<LockVerificationScreen> createState() => _LockVerificationScreenState();
}

class _LockVerificationScreenState extends State<LockVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _verifyInput(String input) {
    final isValid = SecurityService.instance.verifyCustomLock(
      widget.lockType,
      widget.lockData,
      input,
    );

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      if (widget.lockType == LockType.pin) _pinController.clear();
      if (widget.lockType == LockType.password) _passwordController.clear();
      if (widget.lockType == LockType.pattern) {
        // Pattern lock usually clears itself visually on error if we had a controller or key reset
        // For now we rely on the snackbar feedback.
        // Ideally we would reset the pattern view.
        // We can use a UniqueKey to force rebuild if needed, but PatternLock usually handles touch up.
        setState(() {}); // specific key rebuild
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hatalı giriş'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F7), // Slightly opaque or solid
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false), // User cancelled
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.lockType == LockType.pattern)
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: PatternLock(
                    key: ValueKey(
                      DateTime.now().millisecondsSinceEpoch,
                    ), // Force clean on rebuild/error
                    dimension: 3,
                    onInputComplete: (points) {
                      final code = points.join('');
                      _verifyInput(code);
                    },
                  ),
                ),
              ),
            if (widget.lockType == LockType.pin)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Pinput(
                      controller: _pinController,
                      length: 4,
                      obscureText: true,
                      autofocus: true,
                      onCompleted: _verifyInput,
                      defaultPinTheme: PinTheme(
                        width: 60,
                        height: 60,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      focusedPinTheme: PinTheme(
                        width: 60,
                        height: 60,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Colors.blueAccent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      submittedPinTheme: PinTheme(
                        width: 60,
                        height: 60,
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.lockType == LockType.password)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      autofocus: true,
                      obscureText: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Güvenli Parola',
                        hintText: 'Parolayı girin',
                        prefixIcon: const Icon(Icons.lock_open),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                      onSubmitted: _verifyInput,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
