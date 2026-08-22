import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class OcrResult {
  final double? total;
  final String? note;
  final String? category;

  OcrResult({this.total, this.note, this.category});
}

/// OCR service that uses Google Gemini AI for intelligent receipt parsing.
class OcrService {
  /// Sends an image as bytes to Gemini API for text recognition and structured data extraction.
  static Future<OcrResult> processImage(Uint8List imageBytes, String mimeType) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY tidak ditemukan di .env');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final prompt = TextPart(
        '''Ekstrak data dari gambar struk ini.
Aturan:

amount: Cari baris 'Total Belanja'. Ambil angkanya. Jangan ambil dari baris 'Tunai', 'Kembalian', atau 'Total Item'.

title: Ambil nama toko di baris paling atas.

category: Tentukan kategori dari barang yang dibeli (Makanan, Belanja, Transportasi, Hiburan, dll).
Keluarkan HANYA format JSON valid tanpa awalan/akhiran: {"amount": integer, "title": "string", "category": "string"}''');

    final imagePart = DataPart(mimeType, imageBytes);

    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini mengembalikan respons kosong.');
    }

    debugPrint('Gemini response: $text');

    try {
      String rawText = text ?? '{}';
      rawText = rawText.replaceAll(RegExp(r'```json\n?'), '').replaceAll(RegExp(r'```'), '').trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
      final cleanJson = match != null ? match.group(0)! : '{}';
      final data = jsonDecode(cleanJson);

      double? total;
      if (data['amount'] != null) {
        if (data['amount'] is num) {
          total = (data['amount'] as num).toDouble();
        } else if (data['amount'] is String) {
          total = double.tryParse(data['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        }
      }

      return OcrResult(
        total: total,
        note: data['title']?.toString(),
        category: data['category']?.toString(),
      );
    } catch (e) {
      throw Exception('Gagal memparsing JSON dari Gemini: $e\nResponse: $text');
    }
  }
}
