import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/message.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:intl/intl.dart';
import '../models/chat.dart';

class ImportExportService {
  // Proprietary Key for .fs files
  static final _key = encrypt.Key.fromUtf8(
    'ForeSee_Secure_Key_2024_Antigrav',
  ); // 32 chars
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Generates a styled PDF for the given Chat
  Future<File> exportChatAsPdf(Chat chat) async {
    final pdf = pw.Document();
    final font =
        pw.Font.courier(); // Using standard font to avoid loading issues

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ForeSee Sohbet Geçmişi',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 12, font: font),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Konu: ${chat.title}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                font: font,
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 20),
            ...chat.messages.map((m) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      m.isUser ? 'Siz:' : 'ForeSee:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: m.isUser
                            ? PdfColors.blue700
                            : PdfColors.green700,
                        fontSize: 10,
                        font: font,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      m.content,
                      style: pw.TextStyle(fontSize: 10, font: font),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                ),
              );
            }).toList(),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              title: pw.Text(
                'ForeSee ile oluşturuldu',
                style: pw.TextStyle(
                  color: PdfColors.grey,
                  fontSize: 8,
                  font: font,
                ),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = 'foresee_chat_${chat.id}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Moves a file to the Downloads folder (Android/iOS)
  Future<File?> saveToDownloads(File sourceFile, String targetFileName) async {
    try {
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (!await downloadsDirectory.exists()) {
          downloadsDirectory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDirectory = await getApplicationDocumentsDirectory();
      }

      if (downloadsDirectory == null) return null;

      final targetPath = '${downloadsDirectory.path}/$targetFileName';
      return await sourceFile.copy(targetPath);
    } catch (e) {
      print('Error saving to downloads: $e');
      return null;
    }
  }

  /// Encrypts and exports a Chat as a .fs file
  Future<File> exportChatAsFs(Chat chat) async {
    final jsonStr = jsonEncode(chat.toJson());

    // Encrypt
    final encrypted = _encrypter.encrypt(jsonStr, iv: _iv);

    // Create File
    final output = await getTemporaryDirectory();
    final fileName = 'sohbet_${chat.id}.fs';
    final file = File('${output.path}/$fileName');

    // Write Base64 string
    await file.writeAsString(encrypted.base64);

    return file;
  }

  /// Imports and decrypts a .fs file
  Future<Chat?> importChatFromFs(File file) async {
    try {
      final encryptedBase64 = await file.readAsString();

      // Decrypt
      final decrypted = _encrypter.decrypt64(encryptedBase64, iv: _iv);

      // Decode JSON
      final jsonMap = jsonDecode(decrypted);

      // Validate structure (basic check)
      if (jsonMap is Map<String, dynamic> &&
          jsonMap.containsKey('id') &&
          jsonMap.containsKey('messages')) {
        // Regenerate ID to avoid conflicts, or keep it?
        // Better to regenerate ID but keep original title/messages, or append " (Imported)"
        final chat = Chat.fromJson(jsonMap);

        final newId = DateTime.now().millisecondsSinceEpoch.toString();

        // Update messages IDs too? Maybe loop through them.
        // For simplicity, we keep original structure but change Chat ID.

        return chat.copyWith(
          id: newId,
          title: '${chat.title} (İçe Aktarıldı)',
          updatedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Import Error: $e');
      return null;
    }
  }
}
