import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/message.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../models/chat.dart';

class ImportExportService {
  // Proprietary Key for .fs files
  static final _key = encrypt.Key.fromUtf8(
    'ForeSee_Secure_Key_2024_Antigrav',
  ); // 32 chars
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Generates a styled PDF for the given Chat with Images
  Future<File> exportChatAsPdf(Chat chat) async {
    final pdf = pw.Document();

    // Load fonts and logo
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/Betaw.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Logo loading failed: $e');
    }

    // Pre-process messages to load images
    final processedMessages = <Map<String, dynamic>>[];
    for (final m in chat.messages) {
      pw.MemoryImage? contentImage;
      if (m.imageUrl != null) {
        try {
          if (m.imageUrl!.startsWith('data:image')) {
            final base64String = m.imageUrl!.split(',').last;
            contentImage = pw.MemoryImage(base64Decode(base64String));
          } else {
            // File path
            final file = File(m.imageUrl!);
            if (await file.exists()) {
              contentImage = pw.MemoryImage(await file.readAsBytes());
            }
          }
        } catch (_) {}
      }
      processedMessages.add({'msg': m, 'image': contentImage});
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 30),
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  // Logo (Center)
                  if (logoImage != null)
                    pw.Container(height: 24, child: pw.Image(logoImage)),

                  // Row for Title (Left) and Date (Right)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Chat Title
                      pw.Container(
                        width: 150,
                        child: pw.Text(
                          chat.title,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      // Date
                      pw.Text(
                        DateFormat('d/M/yyyy').format(chat.createdAt),
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Messages
            ...processedMessages.map((item) {
              final m = item['msg'] as Message;
              final image = item['image'] as pw.MemoryImage?;
              final isUser = m.isUser;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: isUser
                      ? pw.CrossAxisAlignment.end
                      : pw.CrossAxisAlignment.start,
                  children: [
                    // Message Content
                    pw.Container(
                      padding: isUser
                          ? const pw.EdgeInsets.all(12)
                          : const pw.EdgeInsets.only(
                              top: 0,
                              bottom: 4,
                              left: 0,
                              right: 20,
                            ),
                      decoration: isUser
                          ? pw.BoxDecoration(
                              color: PdfColors.grey300,
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(12),
                              ),
                            )
                          : const pw.BoxDecoration(), // No decoration for AI
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (image != null)
                            pw.Container(
                              height: 150,
                              margin: const pw.EdgeInsets.only(bottom: 8),
                              child: pw.Image(image),
                            ),
                          pw.Text(
                            m.content,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 12,
                              color: PdfColors.black,
                              lineSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Timestamp
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        DateFormat('HH:mm').format(m.timestamp),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                          font: font,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
        // En yaygın ve kullanıcı dostu klasör
        downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (!await downloadsDirectory.exists()) {
          // İkinci deneme (bazı cihazlar için)
          downloadsDirectory = Directory('/sdcard/Download');
          if (!await downloadsDirectory.exists()) {
            downloadsDirectory = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isIOS) {
        downloadsDirectory = await getApplicationDocumentsDirectory();
      } else {
        downloadsDirectory = await getDownloadsDirectory();
      }

      if (downloadsDirectory == null) return null;

      final targetPath = '${downloadsDirectory.path}/$targetFileName';
      return await sourceFile.copy(targetPath);
    } catch (e) {
      print('Error saving to downloads: $e');
      // Son çare: Uygulama özel dış depolama alanı
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final targetPath = '${extDir.path}/$targetFileName';
          return await sourceFile.copy(targetPath);
        }
      } catch (_) {}
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
    final fileName = 'sohbet_${chat.id}.fsa';
    final file = File('${output.path}/$fileName');

    // Write Base64 string
    await file.writeAsString(encrypted.base64);

    return file;
  }

  /// Imports and decrypts a .fs file
  Future<Chat?> importChatFromFs(File file) async {
    try {
      // Read and clean the base64 string
      final encryptedBase64 = (await file.readAsString()).trim();

      if (encryptedBase64.isEmpty) {
        print('Import Error: Dosya boş');
        return null;
      }

      // Decrypt
      final decrypted = _encrypter.decrypt64(encryptedBase64, iv: _iv);

      // Decode JSON in background
      final jsonMap = await compute(jsonDecode, decrypted);

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

      print('Import Error: Geçersiz dosya yapısı');
      return null;
    } catch (e) {}
  }

  /// Exports a Chat as a clean Markdown/Text file (Word compatible)
  Future<File> exportChatAsText(Chat chat) async {
    final buffer = StringBuffer();
    buffer.writeln('# ${chat.title}');
    buffer.writeln(
      'ForeSee Sohbet Geçmişi - ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
    );
    buffer.writeln('==========================================');
    buffer.writeln();

    for (final m in chat.messages) {
      final role = m.isUser ? 'Siz' : 'ForeSee';
      final time = DateFormat('HH:mm').format(m.timestamp);
      buffer.writeln('[$time] $role:');
      buffer.writeln(m.content);
      if (m.imageUrl != null) {
        buffer.writeln('[Görsel Ekli]');
      }
      buffer.writeln('------------------------------------------');
      buffer.writeln();
    }

    final output = await getTemporaryDirectory();
    final fileName = 'foresee_chat_${chat.id}.txt';
    final file = File('${output.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file;
  }
}
