import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

class OcrService {
  static Future<OcrResult> processImage(Uint8List imageBytes, String mimeType) async {
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: const Size(0, 0),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: 0,
      ),
    );
    
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      
      debugPrint('===== OCR FULL TEXT =====');
      debugPrint(fullText);
      debugPrint('========================');
      
      final title = _extractStoreName(fullText);
      final total = _extractTotal(fullText);
      final category = _CategoryMapper.mapCategory(title);
      
      debugPrint('Extracted - Title: $title, Total: $total, Category: $category');
      
      if (total == null || total <= 0) {
        throw Exception('Total tidak ditemukan atau invalid (nilai: $total)');
      }
      
      return OcrResult(
        total: total,
        note: title,
        category: category,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  static String _extractStoreName(String text) {
    final lines = text.split('\n');
    
    for (final line in lines) {
      final clean = line.trim();
      if (clean.isEmpty) continue;
      if (clean.length < 3) continue;
      
      final lower = clean.toLowerCase();
      
      if (lower.contains('alfamart') || lower.contains('indomaret') || 
          lower.contains('minimarket') || lower.contains('batu kandik') ||
          lower.contains('pt.sumber') || lower.contains('alfaria')) {
        return clean;
      }
      
      if (!lower.contains('total') && !lower.contains('item') && 
          !lower.contains('tunai') && !lower.contains('kembalian') &&
          !lower.contains('diskon') && !lower.contains('kasir') && 
          !lower.contains('tanggal') && !lower.contains('rp') &&
          !lower.contains('npwp') && !lower.contains('no.') &&
          !clean.contains(RegExp(r'^\d')) &&
          clean.length > 3 && clean.length < 50) {
        return clean;
      }
    }
    
    return 'Belanja';
  }

  static double? _extractTotal(String text) {
    final lines = text.split('\n');
    double? bestTotal;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];
      
      if (line.contains('total belanja')) {
        final amount = _extractAmountFromLine(originalLine);
        if (amount != null && amount > 0) {
          debugPrint('Found Total Belanja: $amount');
          return amount;
        }
      }
    }
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];
      
      if ((line.contains('total') || line.contains('subtotal')) && 
          !line.contains('item') && !line.contains('diskon') && 
          !line.contains('tunai') && !line.contains('kembalian')) {
        final amount = _extractAmountFromLine(originalLine);
        if (amount != null && amount > 100 && amount < 100000000) {
          if (bestTotal == null || amount > bestTotal) {
            bestTotal = amount;
            debugPrint('Found Total line: $amount from "${originalLine.trim()}"');
          }
        }
      }
    }
    
    if (bestTotal != null) return bestTotal;
    
    final allAmounts = <double>[];
    for (final line in lines) {
      final amounts = RegExp(r'\d+(?:[.,]\d+)?').allMatches(line);
      for (final match in amounts) {
        String numStr = match.group(0)!.replaceAll(',', '.');
        if (numStr.contains('.')) {
          final parts = numStr.split('.');
          if (parts.length == 2 && parts[1].length == 2) {
            final amount = double.tryParse(numStr);
            if (amount != null && amount > 100 && amount < 100000000) {
              allAmounts.add(amount);
            }
          }
        }
      }
    }
    
    if (allAmounts.isNotEmpty) {
      allAmounts.sort();
      bestTotal = allAmounts.last;
      debugPrint('Fallback: largest amount found: $bestTotal');
      return bestTotal;
    }
    
    return null;
  }

  static double? _extractAmountFromLine(String line) {
    final matches = RegExp(r'(\d+)[.,](\d+)').allMatches(line);
    for (final match in matches) {
      final num = match.group(1)!;
      final decimal = match.group(2)!;
      final amount = double.parse('$num.$decimal');
      if (amount > 0 && amount < 100000000) {
        return amount;
      }
    }
    return null;
  }
}
