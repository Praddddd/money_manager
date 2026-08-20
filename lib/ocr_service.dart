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
        '''Kamu adalah sistem ekstraksi struk. Baca struk ini dengan teliti.
Aturan:
amount: Cari nominal AKHIR yang benar-benar dibayarkan (biasanya berlabel 'Total Belanja', 'Total', 'Amount Due'). JANGAN gunakan angka 'Tunai', 'Cash', 'Pay', 'Kembalian', atau total sebelum diskon. Hilangkan titik/koma.
title: Ambil nama toko dari 1-2 baris paling atas (contoh: Alfamart, Indomaret, dll).
category: Tentukan satu kategori (Makanan, Transportasi, Belanja, Hiburan, Tagihan, Lainnya) berdasarkan nama toko atau item barang.
Keluarkan output HANYA JSON murni tanpa teks awalan/akhiran dan TANPA markdown block (jangan pakai ```json).
Contoh output valid: {"amount": 16200, "title": "Alfamart Batu Kandik", "category": "Makanan"}''');

    final imagePart = DataPart(mimeType, imageBytes);

    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini mengembalikan respons kosong.');
    }

    try {
      var cleanText = text.trim();
      // Remove markdown blocks if Gemini accidentally includes them
      cleanText = cleanText.replaceAll(RegExp(r'^```(json)?\s*'), '');
      cleanText = cleanText.replaceAll(RegExp(r'\s*```$'), '');
      
      // Fallback: extract only the JSON object part if there's any prefix/suffix junk text
      final startIndex = cleanText.indexOf('{');
      final endIndex = cleanText.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        cleanText = cleanText.substring(startIndex, endIndex + 1);
      }

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
