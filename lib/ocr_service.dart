import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    );

    final prompt = TextPart(
        'Analisis gambar struk ini. Ekstrak data dan kembalikan HANYA dalam format JSON valid tanpa markdown block (```json) atau teks pengantar apapun. Skema JSON: {"amount": <angka total nominal tanpa titik/simbol>, "title": "<nama merchant/toko>", "category": "<pilih salah satu yang paling cocok: Makanan, Transportasi, Belanja, Hiburan, Tagihan, atau Lainnya>"}');

    final imagePart = DataPart(mimeType, imageBytes);

    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini mengembalikan respons kosong.');
    }

    try {
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> json = jsonDecode(cleanText);

      double? total;
      if (json['amount'] != null) {
        if (json['amount'] is num) {
          total = (json['amount'] as num).toDouble();
        } else if (json['amount'] is String) {
          total = double.tryParse(json['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        }
      }

      return OcrResult(
        total: total,
        note: json['title']?.toString(),
        category: json['category']?.toString(),
      );
    } catch (e) {
      throw Exception('Gagal memparsing JSON dari Gemini: $e\nResponse: $text');
    }
  }
}
