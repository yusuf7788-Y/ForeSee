import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'grey_notification.dart';

class PhoneNumberPanel extends StatelessWidget {
  final String phoneNumber;

  const PhoneNumberPanel({
    super.key,
    required this.phoneNumber,
  });

  Future<void> _addToContacts(BuildContext context, String phone) async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Kişiler izni gerekli');
        return;
      }

      // Telefon numarasını formatla
      String formattedPhone = phone;
      if (!phone.startsWith('+') && !phone.startsWith('00')) {
        if (phone.startsWith('444')) {
          formattedPhone = phone;
        } else if (phone.startsWith('0')) {
          formattedPhone = '+90' + phone.substring(1);
        } else {
          formattedPhone = '+90' + phone;
        }
      }

      final contact = Contact()
        ..phones = [Phone(formattedPhone)]
        ..displayName = phone.startsWith('444') ? phone : 'Bilinmeyen Numara';

      await contact.insert();
      
      if (!context.mounted) return;
      GreyNotification.show(context, 'Kişi rehbere eklendi');
    } catch (e) {
      if (!context.mounted) return;
      GreyNotification.show(context, 'Kişi eklenemedi: $e');
    }
  }

  Future<void> _sendMessage(BuildContext context, String phone) async {
    try {
      // Telefon numarasını formatla - ülke kodu yoksa ekle
      String formattedPhone = phone;
      if (!phone.startsWith('+') && !phone.startsWith('00')) {
        if (phone.startsWith('444')) {
          // 444 numaraları olduğu gibi bırak
          formattedPhone = phone;
        } else if (phone.startsWith('0')) {
          formattedPhone = '+90' + phone.substring(1);
        } else {
          formattedPhone = '+90' + phone;
        }
      }
      
      final uri = Uri.parse('sms:$formattedPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Mesaj gönderilemedi');
      }
    } catch (e) {
      if (!context.mounted) return;
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  Future<void> _readContactInfo(BuildContext context, String phone) async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Kişiler izni gerekli');
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      // Telefon numarasını normalize et
      String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (normalizedPhone.startsWith('90') && normalizedPhone.length > 10) {
        normalizedPhone = normalizedPhone.substring(2); // 90 prefix'ini kaldır
      }

      Contact? matchingContact;
      try {
        matchingContact = contacts.firstWhere(
          (contact) {
            for (final p in contact.phones) {
              String contactPhone = p.number.replaceAll(RegExp(r'[^\d]'), '');
              if (contactPhone.startsWith('90') && contactPhone.length > 10) {
                contactPhone = contactPhone.substring(2);
              }
              if (contactPhone == normalizedPhone) {
                return true;
              }
            }
            return false;
          },
        );
      } catch (e) {
        matchingContact = null;
      }

      if (matchingContact == null) {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Bu numara rehberde bulunamadı');
        return;
      }

      final contact = matchingContact;
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            contact.displayName,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.phones.isNotEmpty) ...[
                const Text(
                  'Telefon:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                ...contact.phones.map((p) => Text(
                  p.number,
                  style: const TextStyle(color: Colors.white),
                )),
                const SizedBox(height: 12),
              ],
              if (contact.emails.isNotEmpty) ...[
                const Text(
                  'E-posta:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                ...contact.emails.map((e) => Text(
                  e.address,
                  style: const TextStyle(color: Colors.white),
                )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  Future<void> _searchInContacts(BuildContext context, String phone) async {
    try {
      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Kişiler izni gerekli');
        return;
      }

      // Rehber uygulamasını aç (Android)
      final uri = Uri.parse('content://contacts/people/');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        GreyNotification.show(context, 'Rehber açılamadı');
      }
    } catch (e) {
      if (!context.mounted) return;
      GreyNotification.show(context, 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    phoneNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildActionButton(
                    context,
                    icon: FontAwesomeIcons.userPlus,
                    label: 'Kişilere ekle',
                    onTap: () {
                      Navigator.pop(context);
                      _addToContacts(context, phoneNumber);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    icon: FontAwesomeIcons.message,
                    label: 'Kişiye mesaj gönder',
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage(context, phoneNumber);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    icon: FontAwesomeIcons.user,
                    label: 'Kişi bilgisi oku',
                    onTap: () {
                      Navigator.pop(context);
                      _readContactInfo(context, phoneNumber);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    icon: FontAwesomeIcons.addressBook,
                    label: 'Rehberde bul',
                    onTap: () {
                      Navigator.pop(context);
                      _searchInContacts(context, phoneNumber);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Haptic feedback
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.blue.withOpacity(0.3),
        highlightColor: Colors.blue.withOpacity(0.1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              FaIcon(
                icon,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

