import 'dart:js_interop';

@JS('performOCR')
external JSPromise<JSString> _performOCR(JSString imageDataUrl);

class OcrResult {
  final double? total;
  final String? note;
  final String? category;

  OcrResult({this.total, this.note, this.category});
}

/// OCR service that uses Tesseract.js via JS interop for web-based receipt scanning.
class OcrService {
  /// Sends a base64 data URL image to Tesseract.js for text recognition.
  static Future<String> recognizeText(String imageDataUrl) async {
    final jsText = await _performOCR(imageDataUrl.toJS).toDart;
    return jsText.toDart;
  }

  /// Processes recognized text to extract total, note, and category.
  static OcrResult processText(String text) {
    return OcrResult(
      total: extractTotal(text),
      note: extractNote(text),
      category: extractCategory(text),
    );
  }

  /// Extracts the most likely title/note from the receipt.
  /// Usually the first prominent text block (store name).
  static String? extractNote(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      // Look for the first line that is reasonably long and contains letters
      if (trimmed.length > 2 && trimmed.contains(RegExp(r'[A-Za-z]{3}'))) {
        // Return max 30 characters
        return trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
      }
    }
    return null;
  }

  /// Extracts the category based on simple keyword mapping.
  static String? extractCategory(String text) {
    final upper = text.toUpperCase();

    // Makan
    if (upper.contains('WARUNG') || upper.contains('KFC') || upper.contains('INDOMARET') ||
        upper.contains('ALFAMART') || upper.contains('MCDONALDS') || upper.contains('MCD') ||
        upper.contains('RESTORAN') || upper.contains('CAFE') || upper.contains('KOPI') ||
        upper.contains('BAKSO') || upper.contains('MIE') || upper.contains('AYAM') ||
        upper.contains('FOOD') || upper.contains('MART')) {
      return 'Makan';
    }
    
    // Transportasi
    if (upper.contains('SPBU') || upper.contains('PERTAMINA') || upper.contains('SHELL') ||
        upper.contains('PARKIR') || upper.contains('GOJEK') || upper.contains('GRAB') ||
        upper.contains('MAXIM') || upper.contains('TOL') || upper.contains('STASIUN')) {
      return 'Transportasi';
    }

    // Tagihan
    if (upper.contains('PLN') || upper.contains('PDAM') || upper.contains('TELKOM') ||
        upper.contains('INDIHOME') || upper.contains('INTERNET') || upper.contains('LISTRIK') ||
        upper.contains('BPJS')) {
      return 'Tagihan';
    }

    // Pendidikan
    if (upper.contains('GRAMEDIA') || upper.contains('BUKU') || upper.contains('STATIONERY') ||
        upper.contains('SEKOLAH') || upper.contains('KURSUS') || upper.contains('KAMPUS')) {
      return 'Pendidikan';
    }

    // Hiburan
    if (upper.contains('CGV') || upper.contains('XXI') || upper.contains('CINEMA') ||
        upper.contains('TIKET') || upper.contains('KARAOKE') || upper.contains('GAME')) {
      return 'Hiburan';
    }

    // Belanja Online
    if (upper.contains('TOKOPEDIA') || upper.contains('SHOPEE') || upper.contains('LAZADA') ||
        upper.contains('BLIBLI') || upper.contains('TIKTOK')) {
      return 'Belanja Online';
    }

    // Kesehatan / Lainnya
    if (upper.contains('APOTEK') || upper.contains('KLINIK') || upper.contains('RUMAH SAKIT') ||
        upper.contains('KESEHATAN') || upper.contains('FARMASI')) {
      return 'Lainnya'; // 'Kesehatan' isn't explicitly in Cat.all, fallback to Lainnya
    }

    return null; // Return null if no keywords match so user can select manually
  }

  /// Extracts the total price from OCR text.
  /// Looks for common receipt patterns: TOTAL, GRAND TOTAL, JUMLAH, BAYAR, etc.
  static double? extractTotal(String text) {
    final lines = text.split('\n');
    double? bestMatch;

    // First pass: look for lines with total-related keywords
    for (final line in lines) {
      final upper = line.toUpperCase().trim();
      if (upper.contains('TOTAL') ||
          upper.contains('JUMLAH') ||
          upper.contains('BAYAR') ||
          upper.contains('TUNAI') ||
          upper.contains('GRAND')) {
        final number = _extractLargestNumber(line);
        if (number != null && number > 0) {
          if (bestMatch == null || number > bestMatch) {
            bestMatch = number;
          }
        }
      }
    }

    // Fallback: if no keyword found, return the largest number in the text
    if (bestMatch == null) {
      for (final line in lines) {
        final number = _extractLargestNumber(line);
        if (number != null && number > 0) {
          if (bestMatch == null || number > bestMatch) {
            bestMatch = number;
          }
        }
      }
    }

    return bestMatch;
  }

  static double? _extractLargestNumber(String text) {
    // Remove currency symbols (Rp, Rp., IDR)
    var cleaned = text.replaceAll(RegExp(r'[Rr][Pp]\.?\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'IDR\s*', caseSensitive: false), '');

    // Match number patterns: 150.000, 150,000, 1.500.000, 150000
    final regex = RegExp(r'(\d{1,3}(?:[.,]\d{3})*|\d+)');
    final matches = regex.allMatches(cleaned);

    double? largest;
    for (final match in matches) {
      var numStr = match.group(0)!;
      // Remove thousand separators (dots and commas used as thousands)
      numStr = numStr.replaceAll('.', '').replaceAll(',', '');
      final value = double.tryParse(numStr);
      if (value != null && value > 0 && (largest == null || value > largest)) {
        largest = value;
      }
    }

    return largest;
  }
}
