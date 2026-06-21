import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

class C {
  static const Color bg = Color(0xFF000000);
  static const Color surface = Color(0xFF080808);
  static const Color card = Color(0xFF0F0F0F);
  static const Color cardAlt = Color(0xFF141414);
  static const Color elevated = Color(0xFF1A1A1A);
  static const Color subtle = Color(0xFF202020);
  static const Color divider = Color(0xFF1E1E1E);

  // Accent — Royal Blue
  static const Color accent = Color(0xFF007AFF);
  static const Color accentSoft = Color(0xFF0A4D8C);

  // Semantic
  static const Color red = Color(0xFFFF453A);
  static const Color green = Color(0xFF30D158);

  // Text hierarchy
  static const Color t1 = Color(0xFFF5F5F7);
  static const Color t2 = Color(0xFF98989D);
  static const Color t3 = Color(0xFF636366);
  static const Color t4 = Color(0xFF3A3A3C);

  // Chart palette
  static const List<Color> chart = [
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFFF9500),
    Color(0xFF30D158),
    Color(0xFFFF453A),
    Color(0xFFFF2D55),
    Color(0xFFAC8E68),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class Expense {
  final String id;
  final double amount;
  final String note;
  final String category;
  final DateTime date;

  const Expense({
    required this.id,
    required this.amount,
    required this.note,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'note': note,
        'category': category,
        'date': date.millisecondsSinceEpoch,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String,
        category: m['category'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════════

class Cat {
  static const List<String> all = [
    'Makan',
    'Belanja Online',
    'Transportasi',
    'Tagihan',
    'Pendidikan',
    'Hiburan',
    'Lainnya',
  ];

  static IconData icon(String c) => switch (c) {
        'Makan' => Icons.restaurant_rounded,
        'Belanja Online' => Icons.shopping_cart_rounded,
        'Transportasi' => Icons.directions_car_rounded,
        'Tagihan' => Icons.receipt_long_rounded,
        'Pendidikan' => Icons.school_rounded,
        'Hiburan' => Icons.movie_rounded,
        'Lainnya' => Icons.more_horiz_rounded,
        _ => Icons.category_rounded,
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATTERS
// ═══════════════════════════════════════════════════════════════════════════════

class Fmt {
  static final _curr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String money(double v) => _curr.format(v);

  static String relativeDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hari ini, ${DateFormat.Hm().format(d)}';
    if (diff == 1) return 'Kemarin, ${DateFormat.Hm().format(d)}';
    return DateFormat('dd MMM, HH:mm').format(d);
  }

  static String dateGroup(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hari Ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('dd MMMM yyyy').format(d);
  }

  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String monthShort(DateTime d) => DateFormat('MMM yyyy').format(d);
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final doubleValue = double.tryParse(cleanText);
    if (doubleValue == null) {
      return oldValue;
    }

    final formatter = NumberFormat.decimalPattern('id');
    final formattedText = formatter.format(doubleValue);

    int selectionEnd = newValue.selection.end;
    if (selectionEnd < 0) selectionEnd = 0;
    if (selectionEnd > newValue.text.length) selectionEnd = newValue.text.length;

    int dotsBeforeCursor = 0;
    for (int i = 0; i < selectionEnd; i++) {
      if (newValue.text[i] == '.') {
        dotsBeforeCursor++;
      }
    }
    final digitsBeforeCursor = selectionEnd - dotsBeforeCursor;

    int newCursorOffset = 0;
    int digitsCount = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (formattedText[i] != '.') {
        digitsCount++;
      }
      if (digitsCount <= digitsBeforeCursor) {
        newCursorOffset = i + 1;
      } else {
        break;
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATABASE HELPER
// ═══════════════════════════════════════════════════════════════════════════════

class DbHelper {
  static const String _table = 'expenses';
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    String dbPath;
    if (kIsWeb) {
      dbPath = 'expense_tracker.db';
    } else {
      final dir = await getDatabasesPath();
      dbPath = p.join(dir, 'expense_tracker.db');
    }

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            note TEXT NOT NULL,
            category TEXT NOT NULL,
            date INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  static Future<void> insert(Expense e) async {
    final db = await database;
    await db.insert(_table, e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Expense>> getAll() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'date DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  static Future<List<Expense>> getByMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    final maps = await db.query(
      _table,
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  static Future<List<DateTime>> getAvailableMonths() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT DISTINCT
        CAST(strftime('%Y', date / 1000, 'unixepoch') AS INTEGER) as year,
        CAST(strftime('%m', date / 1000, 'unixepoch') AS INTEGER) as month
      FROM $_table
      ORDER BY year DESC, month DESC
    ''');
    return results
        .map((r) => DateTime(r['year'] as int, r['month'] as int))
        .toList();
  }

  static Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateExpense(Expense e) async {
    final db = await database;
    await db.update(
      _table,
      e.toMap(),
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _items = [];
  bool _loading = true;

  bool get loading => _loading;

  List<Expense> get all => _items;

  List<Expense> get recent => _items.take(5).toList();

  List<Expense> get thisMonth {
    final now = DateTime.now();
    return _items
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }

  double get total => thisMonth.fold(0.0, (s, e) => s + e.amount);

  double totalForMonth(int year, int month) =>
      forMonth(year, month).fold(0.0, (s, e) => s + e.amount);

  List<Expense> forMonth(int year, int month) =>
      _items.where((e) => e.date.year == year && e.date.month == month).toList();

  Map<String, double> get byCategory {
    final m = <String, double>{};
    for (final e in thisMonth) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  List<DateTime> get availableMonths {
    final months = <String, DateTime>{};
    for (final e in _items) {
      final key = '${e.date.year}-${e.date.month}';
      months.putIfAbsent(key, () => DateTime(e.date.year, e.date.month));
    }
    final list = months.values.toList();
    list.sort((a, b) => b.compareTo(a));
    // Always include current month even if no data
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month}';
    if (!months.containsKey(currentKey)) {
      list.insert(0, DateTime(now.year, now.month));
    }
    return list;
  }

  /// Load all expenses from SQLite
  Future<void> loadExpenses() async {
    _loading = true;
    notifyListeners();
    _items = await DbHelper.getAll();
    _loading = false;
    notifyListeners();
  }

  /// Add expense to SQLite and local cache
  Future<void> add(Expense e) async {
    await DbHelper.insert(e);
    _items.insert(0, e);
    _items.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  /// Delete expense from SQLite and local cache
  Future<void> remove(String id) async {
    await DbHelper.deleteExpense(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Update expense in SQLite and local cache
  Future<void> update(Expense e) async {
    await DbHelper.updateExpense(e);
    final idx = _items.indexWhere((item) => item.id == e.id);
    if (idx != -1) {
      _items[idx] = e;
      notifyListeners();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable sqflite on web
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final provider = ExpenseProvider();
  await provider.loadExpenses();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: C.accent,
          secondary: C.accent,
          surface: C.surface,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN — 2.5s
// ═══════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _inCtrl;
  late final AnimationController _outCtrl;
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;
  late final Animation<double> _screenOut;

  @override
  void initState() {
    super.initState();

    _inCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _iconFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _inCtrl,
          curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
    _iconScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _inCtrl,
          curve: const Interval(0, 0.5, curve: Curves.easeOutBack)),
    );
    _textFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _inCtrl,
          curve: const Interval(0.35, 0.85, curve: Curves.easeOut)),
    );

    _outCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _screenOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _outCtrl, curve: Curves.easeInCubic),
    );

    _inCtrl.forward();

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      _outCtrl.forward().then((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (ctx, a1, a2) => const AppShell(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _outCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_inCtrl, _outCtrl]),
        builder: (context, _) => Opacity(
          opacity: _screenOut.value,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _iconFade.value,
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: C.accent,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: C.accent.withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: _textFade.value,
                  child: Column(
                    children: [
                      Text(
                        'Expense Tracker',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: C.t1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kelola pengeluaranmu',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: C.t3,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP SHELL
// ═══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _pages = [
    DashboardPage(),
    AddExpensePage(),
    HistoryPage(),
    StatsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(_tab), child: _pages[_tab]),
      ),
      bottomNavigationBar: _NavBar(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _NavBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.divider, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Tab(Icons.dashboard_rounded, 'Home', 0, current, onTap),
              _Tab(Icons.add_circle_outline_rounded, 'Tambah', 1, current, onTap),
              _Tab(Icons.receipt_long_rounded, 'Riwayat', 2, current, onTap),
              _Tab(Icons.pie_chart_rounded, 'Statistik', 3, current, onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx;
  final int current;
  final ValueChanged<int> onTap;
  const _Tab(this.icon, this.label, this.idx, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
            horizontal: active ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? C.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: active ? Colors.white : C.t3),
            if (active) ...[
              const SizedBox(width: 7),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Premium card with subtle depth
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  const ExpenseTile({super.key, required this.expense, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: C.accent.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Icon(Cat.icon(expense.category), size: 20, color: C.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.note.isEmpty ? expense.category : expense.note,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: C.t1,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${expense.category}  ·  ${Fmt.relativeDate(expense.date)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: C.t3,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '-${Fmt.money(expense.amount)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: C.red,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _EmptyState(
      {required this.icon, required this.title, this.sub = ''});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: C.elevated,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28, color: C.t4),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: GoogleFonts.inter(
                    color: C.t2,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sub,
                  style: GoogleFonts.inter(color: C.t3, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, prov, _) {
        if (prov.loading) {
          return const Center(
            child: CircularProgressIndicator(color: C.accent),
          );
        }

        return SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header — no profile icon
                      _Stagger(
                        i: 0,
                        ctrl: _anim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Tracker',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: C.t1,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy')
                                  .format(DateTime.now()),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: C.t3,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Total Card
                      _Stagger(
                        i: 1,
                        ctrl: _anim,
                        child: _TotalCard(total: prov.total),
                      ),

                      const SizedBox(height: 16),

                      // Quick stats
                      _Stagger(
                        i: 2,
                        ctrl: _anim,
                        child: Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Bulan Ini',
                                value: '${prov.thisMonth.length}',
                                sub: 'transaksi',
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniStat(
                                label: 'Top Kategori',
                                value: prov.byCategory.isNotEmpty
                                    ? prov.byCategory.keys.first
                                    : '—',
                                sub: prov.byCategory.isNotEmpty
                                    ? Fmt.money(prov.byCategory.values.first)
                                    : 'Belum ada',
                                icon: Icons.category_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Recent header
                      _Stagger(
                        i: 3,
                        ctrl: _anim,
                        child: Text(
                          'Pengeluaran Terakhir',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: C.t1,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              if (prov.recent.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Belum ada pengeluaran',
                    sub: 'Ketuk "Tambah" untuk mencatat pengeluaran pertamamu',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: prov.recent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final expense = prov.recent[i];
                      return _Stagger(
                        i: 4 + i,
                        ctrl: _anim,
                        child: Dismissible(
                          key: ValueKey(expense.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: C.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                          ),
                          onDismissed: (direction) async {
                            final deleted = expense;
                            await prov.remove(deleted.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.delete_outline_rounded, color: C.red, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Pengeluaran dihapus',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: C.t1),
                                    ),
                                  ],
                                ),
                                action: SnackBarAction(
                                  label: 'Urungkan',
                                  textColor: C.accent,
                                  onPressed: () {
                                    prov.add(deleted);
                                  },
                                ),
                                backgroundColor: C.card,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: ExpenseTile(
                            expense: expense,
                            onTap: () => _showEditSheet(context, expense),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.accent,
                  boxShadow: [
                    BoxShadow(
                      color: C.accent.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total Pengeluaran',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: C.t2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            Fmt.money(total),
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: C.t1,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: C.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Fmt.monthYear(DateTime.now()),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: C.t3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: C.accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: C.t3, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: C.t1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(sub,
                style: GoogleFonts.inter(fontSize: 11, color: C.t3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADD EXPENSE PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _cat;

  late final AnimationController _stagger;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnScale;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _btnScale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    _stagger.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate() || _cat == null) {
      if (_cat == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pilih kategori terlebih dahulu',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: C.elevated,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
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
    _stagger.reset();
    _stagger.forward();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
        const SizedBox(width: 10),
        Text('Pengeluaran tersimpan!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: C.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stagger(
                i: 0,
                ctrl: _stagger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tambah Pengeluaran',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: C.t1,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Catat pengeluaranmu',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: C.t3)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Amount
              _Stagger(
                i: 1,
                ctrl: _stagger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('JUMLAH'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amtCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandsFormatter(),
                      ],
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: C.t1,
                      ),
                      decoration: _deco(hint: '0', prefix: 'Rp '),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Masukkan jumlah';
                        final clean = v.replaceAll('.', '');
                        final n = double.tryParse(clean);
                        if (n == null || n <= 0) return 'Jumlah tidak valid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Category
              _Stagger(
                i: 2,
                ctrl: _stagger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('KATEGORI'),
                    const SizedBox(height: 10),
                    _CatGrid(
                      selected: _cat,
                      onSelect: (c) => setState(() => _cat = c),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Note
              _Stagger(
                i: 3,
                ctrl: _stagger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('CATATAN'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteCtrl,
                      style: GoogleFonts.inter(fontSize: 15, color: C.t1),
                      maxLines: 2,
                      decoration: _deco(hint: 'Untuk apa pengeluaran ini?'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit
              _Stagger(
                i: 4,
                ctrl: _stagger,
                child: GestureDetector(
                  onTapDown: (_) => _btnCtrl.forward(),
                  onTapUp: (_) {
                    _btnCtrl.reverse();
                    _submit();
                  },
                  onTapCancel: () => _btnCtrl.reverse(),
                  child: ScaleTransition(
                    scale: _btnScale,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: C.accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: C.accent.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Simpan Pengeluaran',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco({String? hint, String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w800, color: C.t3),
        hintStyle: GoogleFonts.inter(color: C.t3, fontSize: 15),
        filled: true,
        fillColor: C.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: C.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        errorStyle: GoogleFonts.inter(color: C.red, fontSize: 12),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: C.t3,
          letterSpacing: 1.5,
        ));
  }
}

class _CatGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _CatGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Cat.all.map((c) {
        final active = selected == c;
        return GestureDetector(
          onTap: () => onSelect(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? C.accent : C.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? C.accent : C.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Cat.icon(c),
                    size: 16, color: active ? Colors.white : C.t3),
                const SizedBox(width: 8),
                Text(c,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? Colors.white : C.t2,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY PAGE — MONTH FILTER
// ═══════════════════════════════════════════════════════════════════════════════

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late DateTime _sel;
  late final AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _sel = DateTime(now.year, now.month);
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  void _pick(DateTime m) {
    setState(() => _sel = m);
    _stagger.reset();
    _stagger.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, prov, _) {
        final months = prov.availableMonths;
        final filtered = prov.forMonth(_sel.year, _sel.month);
        final total = prov.totalForMonth(_sel.year, _sel.month);

        final grouped = <String, List<Expense>>{};
        for (final e in filtered) {
          grouped.putIfAbsent(Fmt.dateGroup(e.date), () => []).add(e);
        }

        int idx = 0;

        return SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riwayat',
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: C.t1,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(
                        '${filtered.length} pengeluaran · ${Fmt.money(total)}',
                        style: GoogleFonts.inter(fontSize: 13, color: C.t3),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // Month selector
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: months.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final m = months[i];
                      final active =
                          m.year == _sel.year && m.month == _sel.month;
                      return GestureDetector(
                        onTap: () => _pick(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? C.accent : C.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? C.accent : C.divider,
                            ),
                          ),
                          child: Text(
                            Fmt.monthShort(m),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: active ? Colors.white : C.t2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Tidak ada pengeluaran',
                    sub: 'Belum ada catatan untuk bulan ini',
                  ),
                )
              else
                ...grouped.entries.expand((entry) {
                  final hi = idx++;
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: _Stagger(
                          i: hi,
                          ctrl: _stagger,
                          child: Text(
                            entry.key.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.t3,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: entry.value.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final ii = idx++;
                          final expense = entry.value[i];
                          return _Stagger(
                            i: ii,
                            ctrl: _stagger,
                            child: Dismissible(
                              key: ValueKey(expense.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: C.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                              ),
                              onDismissed: (direction) async {
                                final deleted = expense;
                                await prov.remove(deleted.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, color: C.red, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Pengeluaran dihapus',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: C.t1),
                                        ),
                                      ],
                                    ),
                                    action: SnackBarAction(
                                      label: 'Urungkan',
                                      textColor: C.accent,
                                      onPressed: () {
                                        prov.add(deleted);
                                      },
                                    ),
                                    backgroundColor: C.card,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                              child: ExpenseTile(
                                expense: expense,
                                onTap: () => _showEditSheet(context, expense),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ];
                }),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  int _touched = -1;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, prov, _) {
        final cats = prov.byCategory;
        final total = prov.total;
        final entries = cats.entries.toList();

        return SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _Stagger(
                    i: 0,
                    ctrl: _stagger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Statistik',
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: C.t1,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text(
                          'Breakdown · ${Fmt.monthYear(DateTime.now())}',
                          style:
                              GoogleFonts.inter(fontSize: 13, color: C.t3),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),

              if (entries.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Belum ada data',
                    sub: 'Statistik akan muncul setelah kamu menambahkan pengeluaran',
                  ),
                )
              else ...[
                // Pie chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Stagger(
                      i: 1,
                      ctrl: _stagger,
                      child: _Card(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          height: 230,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (ev, resp) {
                                  setState(() {
                                    if (!ev.isInterestedForInteractions ||
                                        resp == null ||
                                        resp.touchedSection == null) {
                                      _touched = -1;
                                      return;
                                    }
                                    _touched = resp.touchedSection!
                                        .touchedSectionIndex;
                                  });
                                },
                              ),
                              sectionsSpace: 3,
                              centerSpaceRadius: 48,
                              sections: _sections(entries, total),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Total
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Stagger(
                      i: 2,
                      ctrl: _stagger,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: C.divider, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Pengeluaran',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: C.t2)),
                            Text(Fmt.money(total),
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: C.accent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final pct = total > 0 ? e.value / total : 0.0;
                      final color = C.chart[i % C.chart.length];
                      return _Stagger(
                        i: 3 + i,
                        ctrl: _stagger,
                        child: _BreakdownTile(
                          category: e.key,
                          amount: e.value,
                          pct: pct,
                          color: color,
                          highlighted: _touched == i,
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _sections(
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    return entries.asMap().entries.map((me) {
      final i = me.key;
      final e = me.value;
      final active = i == _touched;
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      final color = C.chart[i % C.chart.length];

      return PieChartSectionData(
        color: color,
        value: e.value,
        title: active ? '${pct.toStringAsFixed(1)}%' : '',
        radius: active ? 58 : 48,
        titleStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        badgeWidget: !active && pct >= 10
            ? Text('${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))
            : null,
        badgePositionPercentageOffset: 0.6,
      );
    }).toList();
  }
}

class _BreakdownTile extends StatelessWidget {
  final String category;
  final double amount;
  final double pct;
  final Color color;
  final bool highlighted;

  const _BreakdownTile({
    required this.category,
    required this.amount,
    required this.pct,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.06) : C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? color.withValues(alpha: 0.2)
              : C.divider,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Cat.icon(category), size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: C.t1)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      backgroundColor: C.elevated,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(amount),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.t1)),
              const SizedBox(height: 2),
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGGER ANIMATION HELPER
// ═══════════════════════════════════════════════════════════════════════════════

class _Stagger extends StatelessWidget {
  final int i;
  final AnimationController ctrl;
  final Widget child;
  const _Stagger({required this.i, required this.ctrl, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (i * 0.06).clamp(0.0, 0.7);
    final end = (start + 0.3).clamp(0.0, 1.0);

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));

    final fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: ctrl,
          curve: Interval(start, end, curve: Curves.easeOut)),
    );

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) => Opacity(
        opacity: fade.value,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT EXPENSE MODAL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

void _showEditSheet(BuildContext context, Expense expense) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (context) => _EditExpenseSheet(expense: expense),
  );
}

class _EditExpenseSheet extends StatefulWidget {
  final Expense expense;
  const _EditExpenseSheet({required this.expense});

  @override
  State<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<_EditExpenseSheet>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amtCtrl;
  late final TextEditingController _noteCtrl;
  String? _cat;

  late final AnimationController _stagger;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnScale;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.expense.amount.toInt();
    final formatter = NumberFormat.decimalPattern('id');
    _amtCtrl = TextEditingController(text: formatter.format(initialAmount));
    _noteCtrl = TextEditingController(text: widget.expense.note);
    _cat = widget.expense.category;

    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _btnScale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    _stagger.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate() || _cat == null) {
      if (_cat == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pilih kategori terlebih dahulu',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: C.elevated,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    setState(() => _submitting = true);

    final updated = Expense(
      id: widget.expense.id,
      amount: double.parse(_amtCtrl.text.replaceAll('.', '')),
      note: _noteCtrl.text.trim(),
      category: _cat!,
      date: widget.expense.date,
    );

    await context.read<ExpenseProvider>().update(updated);

    setState(() => _submitting = false);
    
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
        const SizedBox(width: 10),
        Text('Perubahan disimpan!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: C.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: C.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pull handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _Stagger(
                    i: 0,
                    ctrl: _stagger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubah Pengeluaran',
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: C.t1,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('Perbarui detail pengeluaranmu',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: C.t3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Amount
                  _Stagger(
                    i: 1,
                    ctrl: _stagger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('JUMLAH'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amtCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            ThousandsFormatter(),
                          ],
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: C.t1,
                          ),
                          decoration: _deco(hint: '0', prefix: 'Rp '),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Masukkan jumlah';
                            final clean = v.replaceAll('.', '');
                            final n = double.tryParse(clean);
                            if (n == null || n <= 0) return 'Jumlah tidak valid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Category
                  _Stagger(
                    i: 2,
                    ctrl: _stagger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('KATEGORI'),
                        const SizedBox(height: 10),
                        _CatGrid(
                          selected: _cat,
                          onSelect: (c) => setState(() => _cat = c),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Note
                  _Stagger(
                    i: 3,
                    ctrl: _stagger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('CATATAN'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _noteCtrl,
                          style: GoogleFonts.inter(fontSize: 15, color: C.t1),
                          maxLines: 2,
                          decoration: _deco(hint: 'Untuk apa pengeluaran ini?'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  _Stagger(
                    i: 4,
                    ctrl: _stagger,
                    child: GestureDetector(
                      onTapDown: (_) => _btnCtrl.forward(),
                      onTapUp: (_) {
                        _btnCtrl.reverse();
                        _submit();
                      },
                      onTapCancel: () => _btnCtrl.reverse(),
                      child: ScaleTransition(
                        scale: _btnScale,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: C.accent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: C.accent.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Simpan Perubahan',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco({String? hint, String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w800, color: C.t3),
        hintStyle: GoogleFonts.inter(color: C.t3, fontSize: 15),
        filled: true,
        fillColor: C.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: C.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        errorStyle: GoogleFonts.inter(color: C.red, fontSize: 12),
      );
}
