import 'package:astraterm/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AstraTerm foundation renders its welcome screen', (tester) async {
    await tester.pumpWidget(const AstraTermApp());

    expect(find.text('AstraTerm'), findsOneWidget);
    expect(find.text('AstraTerm terminal'), findsOneWidget);
    expect(find.text('Execution engine: not connected'), findsOneWidget);
  });
}
