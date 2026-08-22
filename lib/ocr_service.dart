import 'dart:io';
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
    final inputImage = InputImage.fromBytes(bytes: imageBytes, metadata: InputImageMetadata(size: const Size(0, 0), rotation: InputImageRotation.rotation0deg, format: InputImageFormat.bgra8888, bytesPerRow: 0));
    
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text.toLowerCase();
      
      debugPrint('OCR extracted text:\n$fullText');
      
      final title = _extractStoreName(fullText);
      final total = _extractTotal(fullText);
      final category = _CategoryMapper.mapCategory(title);
      
      if (total == null || total <= 0) {
        throw Exception('Total tidak ditemukan atau invalid');
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
      if (clean.contains('pt.sumber') || clean.contains('alfaria') || clean.contains('alfamart') || 
          clean.contains('indomaret') || clean.contains('batu kandik') || clean.contains('toko')) {
        return clean.replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
      }
      if (!clean.contains('total') && !clean.contains('item') && !clean.contains('rp') && 
          !clean.contains('diskon') && !clean.contains('tunai') && !clean.contains('kembalian') &&
          !clean.contains('kasir') && !clean.contains('tanggal')) {
        return clean.replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
      }
    }
    
    return 'Belanja';
  }

  static double? _extractTotal(String text) {
    final lines = text.split('\n');
    double? largestAmount;
    
    for (final line in lines) {
      if (line.contains('total belanja')) {
        final match = RegExp(r'(\d+)[.,]?(\d*)').firstMatch(line);
        if (match != null) {
          final num = match.group(1)!;
          final decimal = match.group(2);
          final amount = double.parse('$num${decimal != null && decimal.isNotEmpty ? '.$decimal' : '.0'}');
          if (amount > 0) return amount;
        }
      }
    }
    
    for (final line in lines) {
      if (line.contains('total') && !line.contains('item') && !line.contains('diskon') && 
          !line.contains('tunai') && !line.contains('kembalian')) {
        final match = RegExp(r'(\d+)[.,]?(\d*)').firstMatch(line);
        if (match != null) {
          final num = match.group(1)!;
          final decimal = match.group(2);
          final amount = double.parse('$num${decimal != null && decimal.isNotEmpty ? '.$decimal' : '.0'}');
          if (amount > 0 && amount < 10000000) {
            if (largestAmount == null || amount > largestAmount) {
              largestAmount = amount;
            }
          }
        }
      }
    }
    
    if (largestAmount != null) return largestAmount;
    
    for (final line in lines) {
      final match = RegExp(r'(\d+)[.,]?(\d*)').firstMatch(line);
      if (match != null) {
        final num = match.group(1)!;
        final decimal = match.group(2);
        final amount = double.parse('$num${decimal != null && decimal.isNotEmpty ? '.$decimal' : '.0'}');
        if (amount > 100 && amount < 10000000) {
          if (largestAmount == null || amount > largestAmount) {
            largestAmount = amount;
          }
        }
      }
    }
    
    return largestAmount;
  }
}
