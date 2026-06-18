import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carguard_ai/app.dart';

void main() {
  testWidgets('App loads splash route', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CarGuardApp()));
    expect(find.text('CarGuard AI'), findsOneWidget);
  });
}
