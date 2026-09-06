import 'package:flutter_test/flutter_test.dart';

import 'package:vinerox_mobile/main.dart';

void main() {
  testWidgets('app boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const VineroxApp());
    await tester.pump();

    expect(find.byType(VineroxApp), findsOneWidget);
  });
}

