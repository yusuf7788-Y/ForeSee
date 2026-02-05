import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/lock_type.dart';
import '../services/security_service.dart';
import '../widgets/pattern_lock.dart';

class LockSetupScreen extends StatefulWidget {
  final bool initialSetup;

  const LockSetupScreen({super.key, this.initialSetup = true});

  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen> {
  int _step = 0; // 0: Select Type, 1: Input, 2: Confirm
  LockType _selectedType = LockType.none;
  String? _firstInput;
  String _title = 'Kilit Yöntemi Seçin';
  String _subtitle = 'Gizli klasörünüzü nasıl korumak istersiniz?';
  bool _canUseBiometrics = false;

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

  void _onTypeSelected(LockType type) async {
    setState(() {
      _selectedType = type;
      _step = 1;
      _updateTitles();
    });
  }

  void _updateTitles() {
    if (_step == 0) {
      _title = 'Kilit Yöntemi Seçin';
      _subtitle = 'Gizli klasörünüzü nasıl korumak istersiniz?';
    } else if (_step == 1) {
      switch (_selectedType) {
        case LockType.pattern:
          _title = 'Desen Çizin';
          _subtitle = 'En az 4 nokta birleştirin';
          break;
        case LockType.pin:
          _title = 'PIN Oluşturun';
          _subtitle = '4-6 haneli bir kod girin';
          break;
        case LockType.password:
          _title = 'Parola Oluşturun';
          _subtitle = 'Güçlü bir parola belirleyin';
          break;
        case LockType.none:
          break;
      }
    } else if (_step == 2) {
      _title = 'Tekrar Girin';
      _subtitle = 'Doğrulamak için aynısını girin';
    }
  }

  void _handleInput(String input) {
    if (_step == 1) {
      // First input validation
      if (_selectedType == LockType.pattern && input.length < 4) {
        _showError('Desen çok kısa (en az 4 nokta)');
        return;
      }
      if (_selectedType == LockType.password && input.length < 4) {
        _showError('Parola çok kısa');
        return;
      }

      setState(() {
        _firstInput = input;
        _step = 2;
        _updateTitles();
        // Clear inputs for confirmation step
        _pinController.clear();
        _passwordController.clear();
      });
    } else if (_step == 2) {
      // Confirmation
      if (input == _firstInput) {
        // Success
        final hashed = SecurityService.instance.createLockHash(input);
        Navigator.pop(context, {'type': _selectedType, 'data': hashed});
      } else {
        _showError('Eşleşmedi, tekrar deneyin');
        setState(() {
          _step = 1; // Restart input
          _firstInput = null;
          _updateTitles();
          _pinController.clear();
          _passwordController.clear();
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(_step == 0 ? 'Kilit Kurulumu' : 'Şifre Belirle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_step > 0) {
              setState(() {
                _step = 0;
                _firstInput = null;
                _updateTitles();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: _step == 0 ? _buildTypeSelection() : _buildInputArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildOptionCard(
          icon: Icons.grid_on,
          title: 'Desen',
          subtitle: 'Noktaları birleştirerek şifreleyin',
          onTap: () => _onTypeSelected(LockType.pattern),
        ),
        _buildOptionCard(
          icon: Icons.dialpad,
          title: 'PIN',
          subtitle: '4-6 haneli sayısal kod',
          onTap: () => _onTypeSelected(LockType.pin),
        ),
        _buildOptionCard(
          icon: Icons.password,
          title: 'Parola',
          subtitle: 'Harf ve rakam içeren güçlü şifre',
          onTap: () => _onTypeSelected(LockType.password),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: theme.primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.disabledColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    switch (_selectedType) {
      case LockType.pattern:
        return Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: PatternLock(
              key: ValueKey('pattern_$_step'), // Force rebuild to clear pattern
              dimension: 3,
              onInputComplete: (points) {
                // Determine logic for re-input vs first input
                // Convert list to string "0123"
                final code = points.join('');
                _handleInput(code);
              },
            ),
          ),
        );
      case LockType.pin:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Pinput(
                controller: _pinController,
                length: 4,
                obscureText: true,
                autofocus: true,
                onCompleted: _handleInput,
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
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
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
                    border: Border.all(color: Colors.blueAccent, width: 2),
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
              const SizedBox(height: 40),
            ],
          ),
        );
      case LockType.password:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
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
                      hintText: 'Parolanızı girin',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    onSubmitted: _handleInput,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
