import 'dart:js_interop';

@JS('downloadFile')
external void _downloadFile(
    JSString content, JSString filename, JSString mimeType);

/// Utility class for exporting data to CSV format and triggering browser download.
class CsvExport {
  /// Generates a CSV file from headers and rows, then triggers a browser download.
  static void export({
    required List<String> headers,
    required List<List<String>> rows,
    required String filename,
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM for Excel compatibility
    buffer.write('\uFEFF');
    buffer.writeln(headers.join(','));
    for (final row in rows) {
      buffer.writeln(
        row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      );
    }
    _downloadFile(
      buffer.toString().toJS,
      filename.toJS,
      'text/csv;charset=utf-8;'.toJS,
    );
  }
}
