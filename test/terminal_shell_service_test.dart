import 'dart:async';

import 'package:astraterm/services/terminal_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real MockStreamHandler subclass that records its event sink so tests can
/// emit events and that stays silent when no events are emitted.
class _RecordingStreamHandler extends MockStreamHandler {
  Object? arguments;
  StreamController<Object?> controller = StreamController<Object?>();

  void emitData(Map<Object?, Object?> event) => controller.add(event);

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    this.arguments = arguments;
    controller.stream.listen(
      (event) => events.success(event as Map<Object?, Object?>),
    );
  }

  @override
  void onCancel(Object? arguments) {}
}

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

  tearDown(() {
    messenger.setMockMethodCallHandler(TerminalChannels.method, null);
    messenger.setMockStreamHandler(TerminalChannels.output, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('start invokes the platform start method and reaches connected',
      () async {
    final methodCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      methodCalls.add(call);
      return 'started';
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    expect(service.isSupported, isTrue);

    await service.start();
    expect(service.state.value, TerminalEngineState.connected);
    expect(methodCalls.single.method, 'start');

    await service.dispose();
  });

  test('start PlatformException drives the error state and log entry',
      () async {
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      throw PlatformException(
          code: 'spawn_failed', message: '/system/bin/sh unreachable');
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    await service.start();

    expect(service.state.value, TerminalEngineState.error);
    expect(service.lastError.value, '/system/bin/sh unreachable');
    expect(
      service.entries.value.last,
      isA<OutputEntry>(),
    );
    expect(service.entries.value.last.text,
        '* shell error: /system/bin/sh unreachable');

    await service.dispose();
  });

  test('output events append to the log and exit events end the session',
      () async {
    messenger.setMockMethodCallHandler(
        TerminalChannels.method, (call) async => 'started');
    final handler = _RecordingStreamHandler();
    messenger.setMockStreamHandler(TerminalChannels.output, handler);

    final service = TerminalShellService();
    await service.start();

    handler.emitData({'type': 'data', 'data': 'hello\n'});
    handler.emitData({'type': 'data', 'data': 'second line\n'});
    handler.emitData({'type': 'exit', 'code': 0});
    await pumpEventQueue();

    final entries = service.entries.value;
    expect(entries[0], isA<OutputEntry>());
    // Consecutive chunks merge into a single entry (multiline output).
    expect(entries[0].text, 'hello\nsecond line\n');
    expect(entries[1].text, '* shell exited (exit code 0).');
    expect(service.state.value, TerminalEngineState.exited);

    await service.dispose();
  });

  test('write forwards commands to the platform and echoes them', () async {
    final methodCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      methodCalls.add(call);
      return 'written';
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    await service.start();
    await service.write('echo hello');

    final writeCall = methodCalls.where((c) => c.method == 'write').single;
    expect(writeCall.arguments, {'command': 'echo hello'});
    expect(service.entries.value.first, isA<CommandEntry>());
    expect((service.entries.value.first as CommandEntry).command, 'echo hello');

    await service.dispose();
  });

  test('write while disconnected records the command without pretending it ran',
      () async {
    final methodCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      methodCalls.add(call);
      return 'started';
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    await service.write('echo idle');
    expect(
      service.entries.value.last.text,
      '* shell not running; start a session first.',
    );
    expect(methodCalls, isEmpty);

    await service.dispose();
  });

  test('write failure surfaces a write error entry and error state', () async {
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      if (call.method == 'start') return 'started';
      throw PlatformException(code: 'write_failed', message: 'broken pipe');
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    await service.start();
    await service.write('echo hello');

    expect(service.state.value, TerminalEngineState.error);
    expect(
      service.entries.value.last.text,
      '* write error: broken pipe',
    );

    await service.dispose();
  });

  test('close invokes the platform close method and resets state', () async {
    final methodCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      methodCalls.add(call);
      return 'closed';
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    await service.start();
    expect(service.state.value, TerminalEngineState.connected);

    await service.close();
    expect(service.state.value, TerminalEngineState.idle);
    expect(methodCalls.last.method, 'close');

    await service.dispose();
  });

  test('unsupported platforms never touch channels and stay unsupported',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final methodCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(TerminalChannels.method, (call) async {
      methodCalls.add(call);
      return 'started';
    });
    messenger.setMockStreamHandler(
        TerminalChannels.output, _SilentStreamHandler());

    final service = TerminalShellService();
    expect(service.isSupported, isFalse);
    expect(service.state.value, TerminalEngineState.unsupported);

    await service.start();
    await service.write('echo hello');
    await service.close();

    expect(methodCalls, isEmpty);
    expect(service.entries.value, isEmpty);

    await service.dispose();
  });
}
