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
        '''Ekstrak data dari struk belanja Indonesia. PENTING: Keluarkan HANYA JSON tanpa markdown atau teks tambahan.

INSTRUKSI KETAT:

1. amount: Cari baris yang TEPAT berisi "Total Belanja" (bukan "Total Item", bukan "Total Disc", bukan "Tunai", bukan "Kembalian"). Angka di samping "Total Belanja" adalah yang dicari. Contoh struk Alfamart:
   - Total Item: 18.100 ← JANGAN AMBIL INI
   - Total Disc: 1.900 ← JANGAN AMBIL INI
   - Total Belanja: 16.200 ← AMBIL INI
   - Tunai: 50.000 ← JANGAN AMBIL INI
   - Kembalian: 33.800 ← JANGAN AMBIL INI
   
   Jika tidak ada "Total Belanja", cari "TOTAL:" atau jumlah terbesar yang logical sebagai total transaksi. Nilai harus integer positif tanpa titik ribuan.

2. title: Ambil nama toko/merchant dari baris paling atas (bukan alamat, bukan keterangan). Contoh: "ALFAMART", "INDOMARET", "BATU KANDIK", dst.

3. category: Berdasarkan nama toko atau barang, tentukan kategori (Makanan, Belanja Online, Transportasi, Tagihan, Pendidikan, Hiburan, Lainnya).

OUTPUT: {"amount": <integer_tanpa_titik>, "title": "<string>", "category": "<string>"}'''
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

      String mappedCategory = _CategoryMapper.mapCategory(data['category']?.toString());
      
      return OcrResult(
        total: total,
        note: data['title']?.toString(),
        category: mappedCategory,
      );
    } catch (e) {
      throw Exception('Gagal memparsing JSON dari Gemini: $e\nResponse: $text');
    }
  }
}
