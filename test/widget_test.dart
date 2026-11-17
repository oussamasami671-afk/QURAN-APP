import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_app/app/quran_app.dart';

void main() {
  testWidgets('home screen shows Quran app title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuranApp()));
    await tester.pumpAndSettle();
    expect(find.text('القرآن الكريم'), findsOneWidget);
    expect(find.text('متابعة القراءة'), findsOneWidget);
  });
}
