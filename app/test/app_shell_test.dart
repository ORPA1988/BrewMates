import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/main.dart';

void main() {
  testWidgets('App startet und zeigt Feed mit Session-FAB',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrewMatesApp()));
    await tester.pumpAndSettle();

    expect(find.text('BrewMates'), findsOneWidget);
    expect(find.text('Session'), findsOneWidget); // FAB
    expect(find.text('Gerade unterwegs 🍻'), findsOneWidget);
  });

  testWidgets('Session-FAB öffnet den Start-Screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrewMatesApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(find.text('🍺 Bier-Zeit!'), findsOneWidget);
    expect(find.text('Nur ich (Stealth)'), findsOneWidget);
  });
}
