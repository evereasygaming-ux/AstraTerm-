import 'package:astraterm/main.dart';
import 'package:astraterm/services/terminal_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      return switch (call.method) {
        'start' => 'started',
        'write' => 'written',
        'close' => 'closed',
        _ => null,
      };
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(TerminalChannels.method, null);
    messenger.setMockStreamHandler(TerminalChannels.output, null);
  });

  testWidgets('AstraTerm renders the terminal shell home screen',
      (tester) async {
    await tester.pumpWidget(const AstraTermApp());
    await tester.pump();

    expect(find.text('AstraTerm'), findsOneWidget);
    expect(find.text('AstraTerm terminal'), findsOneWidget);
    expect(find.text('CONNECTED'), findsOneWidget);
  });

  testWidgets('submitting a command echoes it into the console',
      (tester) async {
    await tester.pumpWidget(const AstraTermApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'echo hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(find.text('echo hello'), findsOneWidget);
    expect(find.textContaining('* shell not running'), findsNothing);
  });
}
