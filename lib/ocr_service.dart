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

class _CategoryMapper {
  static const Map<String, String> categoryMapping = {
    'Makanan': 'Makan',
    'Makan': 'Makan',
    'Restoran': 'Makan',
    'Kafe': 'Makan',
    'Warung': 'Makan',
    'Indomaret': 'Belanja Online',
    'Alfamart': 'Belanja Online',
    'Minimarket': 'Belanja Online',
    'Supermarket': 'Belanja Online',
    'Toko': 'Belanja Online',
    'Belanja': 'Belanja Online',
    'Transportasi': 'Transportasi',
    'Gojek': 'Transportasi',
    'Grab': 'Transportasi',
    'Taksi': 'Transportasi',
    'Bus': 'Transportasi',
    'Kereta': 'Transportasi',
    'Tagihan': 'Tagihan',
    'Internet': 'Tagihan',
    'Listrik': 'Tagihan',
    'Air': 'Tagihan',
    'Telepon': 'Tagihan',
    'Pendidikan': 'Pendidikan',
    'Sekolah': 'Pendidikan',
    'Universitas': 'Pendidikan',
    'Kursus': 'Pendidikan',
    'Hiburan': 'Hiburan',
    'Bioskop': 'Hiburan',
    'Gaming': 'Hiburan',
    'Musik': 'Hiburan',
    'Film': 'Hiburan',
  };

  static String mapCategory(String? rawCategory) {
    if (rawCategory == null || rawCategory.isEmpty) return 'Lainnya';
    
    final clean = rawCategory.trim().toLowerCase();
    
    for (final entry in categoryMapping.entries) {
      if (clean.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return 'Lainnya';
  }
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
        '''Ekstrak struk belanja. Keluarkan HANYA JSON murni tanpa apapun.

Cari ini:
- amount: Angka di belakang kata "Total Belanja" (tidak "Total Item", "Tunai", "Kembalian"). Jika tidak ada "Total Belanja", ambil angka terbesar di struk. Output: integer saja (16200, bukan 16.200).
- title: Nama toko di baris pertama/atas struk.
- category: Kategori dari nama toko atau barang.

{"amount": 16200, "title": "ALFAMART", "category": "Belanja Online"}'''
    );

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
          final cleanAmount = data['amount'].toString().replaceAll('.', '').replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '');
          total = double.tryParse(cleanAmount);
        }
      }

      String title = data['title']?.toString() ?? 'Belanja';
      String rawCategory = data['category']?.toString() ?? '';
      String mappedCategory = _CategoryMapper.mapCategory(rawCategory.isNotEmpty ? rawCategory : title);
      
      if (total == null || total <= 0) {
        throw Exception('Total tidak valid atau kosong');
      }
      
      return OcrResult(
        total: total,
        note: title,
        category: mappedCategory,
      );
    } catch (e) {
      debugPrint('OCR Error: $e');
      throw Exception('Gagal memparsing JSON dari Gemini: $e\nResponse: $text');
    }
  }
}
