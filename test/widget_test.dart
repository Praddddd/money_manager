
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:money_manager/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    final provider = ExpenseProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const App(),
      ),
    );

    expect(find.text('Expense Tracker'), findsOneWidget);
    
    // Pump a single large duration to trigger and complete the splash screen timer,
    // avoiding pumpAndSettle which hangs on CircularProgressIndicator's infinite animation.
    await tester.pump(const Duration(seconds: 3));
  });
}
