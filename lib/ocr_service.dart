import 'dart:js_interop';

@JS('performOCR')
external JSPromise<JSString> _performOCR(JSString imageDataUrl);

/// OCR service that uses Tesseract.js via JS interop for web-based receipt scanning.
class OcrService {
  /// Sends a base64 data URL image to Tesseract.js for text recognition.
  static Future<String> recognizeText(String imageDataUrl) async {
    final jsText = await _performOCR(imageDataUrl.toJS).toDart;
    return jsText.toDart;
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
