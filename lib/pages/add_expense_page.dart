import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../ocr_service.dart';

class AddExpensePageV2 extends StatefulWidget {
  const AddExpensePageV2({super.key});

  @override
  State<AddExpensePageV2> createState() => _AddExpensePageV2State();
}

class _AddExpensePageV2State extends State<AddExpensePageV2> {
  final _formKey = GlobalKey<FormState>();
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _cat;
  bool _scanning = false;
  bool _submitting = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        setState(() => _scanning = false);
        return;
      }

      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? 'image/jpeg';
      final result = await OcrService.processImage(bytes, mimeType);

      setState(() => _scanning = false);

      if (!mounted) return;

      if (result.total != null && result.total! > 0) {
        _showScanPreview(result);
      } else {
        _showError('Tidak dapat mendeteksi total. Coba foto ulang.');
      }
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) _showError('Error: $e');
    }
  }

  void _showScanPreview(OcrResult result) {
    final formatter = NumberFormat.decimalPattern('id');
    final formattedAmount = formatter.format(result.total!.toInt());
    
    String categoryToShow = result.category ?? 'Lainnya';
    if (!Cat.all.contains(categoryToShow)) {
      categoryToShow = 'Lainnya';
    }
    
    String noteToShow = result.note ?? 'Belanja';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Verifikasi Data Scan',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: C.t1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewField('Jumlah', 'Rp $formattedAmount', C.accent),
            const SizedBox(height: 12),
            _previewField('Toko', noteToShow, C.accent),
            const SizedBox(height: 12),
            _previewField('Kategori', categoryToShow, C.accent),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: C.t2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyScanResult(formattedAmount, noteToShow, categoryToShow);
            },
            child: Text('Terapkan', style: GoogleFonts.inter(color: C.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _previewField(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: C.t3, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: C.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _applyScanResult(String amount, String note, String category) {
    _amtCtrl.text = amount;
    _noteCtrl.text = note;
    setState(() => _cat = category);
    _showSuccess('Data diterapkan! Tinggal klik Simpan.');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: C.red, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: C.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: C.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate() || _cat == null) {
      _showError('Lengkapi semua field dan pilih kategori');
      return;
    }

    setState(() => _submitting = true);

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: double.parse(_amtCtrl.text.replaceAll('.', '')),
      note: _noteCtrl.text.trim(),
      category: _cat!,
      date: DateTime.now(),
    );

    await context.read<ExpenseProvider>().add(expense);

    _amtCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _cat = null;
      _submitting = false;
    });

    if (!mounted) return;
    _showSuccess('Pengeluaran tersimpan!');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah Pengeluaran',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: C.t1,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Catat pengeluaran baru kamu',
                style: GoogleFonts.inter(fontSize: 14, color: C.t3),
              ),
              const SizedBox(height: 32),

              Text(
                'JUMLAH',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: C.t3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.divider, width: 1),
                ),
                child: TextFormField(
                  controller: _amtCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: C.t1),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: C.t2),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: C.elevated.withValues(alpha: 0.5),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Masukkan jumlah';
                    final clean = v.replaceAll('.', '');
                    if (double.tryParse(clean) == null) return 'Jumlah tidak valid';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _scanning ? null : _scanReceipt,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.accent, width: 2),
                          color: C.accent.withValues(alpha: 0.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner_rounded, color: C.accent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _scanning ? 'Memproses...' : 'Scan Struk',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: C.accent,
                              ),
                            ),
                            if (_scanning) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  color: C.accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Text(
                'KATEGORI',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: C.t3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Cat.all.map((cat) {
                  final active = _cat == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? C.accent : C.elevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? C.accent : C.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Cat.icon(cat), size: 16, color: active ? Colors.white : C.t2),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : C.t2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              Text(
                'CATATAN',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: C.t3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.divider, width: 1),
                ),
                child: TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14, color: C.t1),
                  decoration: InputDecoration(
                    hintText: 'Deskripsi pengeluaran (opsional)',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    filled: true,
                    fillColor: C.elevated.withValues(alpha: 0.5),
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: C.t4),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _submitting ? C.accent.withValues(alpha: 0.5) : C.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Simpan Pengeluaran',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
