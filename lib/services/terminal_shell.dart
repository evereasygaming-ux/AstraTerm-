import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channels exposed by the Phase 2.1 Android shell engine.
class TerminalChannels {
  static const MethodChannel method = MethodChannel('com.astra.term/terminal');
  static const EventChannel output =
      EventChannel('com.astra.term/terminal_output');
}

/// Lifecycle states of the Android shell engine session.
enum TerminalEngineState {
  /// No session has been started yet.
  idle,

  /// A start request is in flight.
  starting,

  /// The shell process is alive and accepting commands.
  connected,

  /// The shell process has ended.
  exited,

  /// The last operation failed (platform error or engine unavailable).
  error,

  /// The current platform does not provide the shell engine.
  unsupported,
}

/// A single entry rendered in the terminal log.
sealed class TerminalEntry {
  const TerminalEntry(this.text);

  final String text;
}

/// A command submitted by the user.
class CommandEntry extends TerminalEntry {
  const CommandEntry(super.text);

  String get command => text;
}

/// Output streamed from the shell engine, possibly covering multiple lines.
/// Status notices (errors, exit) are OutputEntries that never merge with
/// streamed data so they remain distinct in the log.
class OutputEntry extends TerminalEntry {
  const OutputEntry(super.text, {this.mergeable = true});

  /// Whether this entry may absorb further streamed chunks.
  final bool mergeable;
}

/// Dart side of the Phase 2.1 Android shell engine.
///
/// Talks to the native adapter through the "com.astra.term/terminal"
/// MethodChannel and streams merged stdout/stderr chunks from the
/// "com.astra.term/terminal_output" EventChannel. On platforms without the
/// Android engine the service degrades gracefully to [TerminalEngineState.unsupported]
/// and never touches the channels.
class TerminalShellService {
  TerminalShellService() {
    _supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (_supported) {
      _subscribe();
    } else {
      state.value = TerminalEngineState.unsupported;
    }
  }

  final ValueNotifier<TerminalEngineState> state =
      ValueNotifier(TerminalEngineState.idle);

  final ValueNotifier<List<TerminalEntry>> entries = ValueNotifier(const []);

  final ValueNotifier<String?> lastError = ValueNotifier(null);

  /// Upper bound on stored entries so streamed output cannot grow unbounded.
  static const int _maxEntries = 500;

  StreamSubscription<Object?>? _outputSubscription;
  bool _supported = false;
  bool _startInFlight = false;

  bool get isSupported => _supported;

  bool get isConnected => state.value == TerminalEngineState.connected;

  /// Starts the persistent Android system shell session.
  Future<void> start() async {
    if (!_supported || _startInFlight) return;
    if (isConnected) return;

    // Re-subscribe: after a previous session ended, the native side sends
    // endOfStream and the old stream subscription is done for good.
    _subscribe();
    _startInFlight = true;
    state.value = TerminalEngineState.starting;
    lastError.value = null;
    try {
      final result =
          await TerminalChannels.method.invokeMethod<String>('start');
      if (result == 'already_running') {
        state.value = TerminalEngineState.connected;
        return;
      }
      state.value = TerminalEngineState.connected;
    } on PlatformException catch (error) {
      state.value = TerminalEngineState.error;
      lastError.value = error.message ?? error.code;
      _append(
        OutputEntry('* shell error: ${error.message ?? error.code}',
            mergeable: false),
      );
    } on MissingPluginException {
      state.value = TerminalEngineState.error;
      lastError.value = 'Terminal engine is unavailable on this device.';
      _append(const OutputEntry('* terminal engine is unavailable.',
          mergeable: false));
    } finally {
      _startInFlight = false;
    }
  }

  /// Submits a command to the shell. The command is echoed into the log; if
  /// the session is not running a clear notice is appended instead of
  /// pretending the command ran.
  Future<void> write(String command) async {
    final raw = command.trimRight();
    if (raw.trim().isEmpty || !_supported) return;

    _append(CommandEntry(raw));
    if (state.value != TerminalEngineState.connected) {
      _append(const OutputEntry('* shell not running; start a session first.',
          mergeable: false));
      return;
    }
    try {
      await TerminalChannels.method
          .invokeMethod<String>('write', {'command': raw});
    } on PlatformException catch (error) {
      state.value = TerminalEngineState.error;
      lastError.value = error.message ?? error.code;
      _append(
        OutputEntry('* write error: ${error.message ?? error.code}',
            mergeable: false),
      );
    }
  }

  /// Requests the native side to terminate the current shell session.
  Future<void> close() async {
    if (!_supported) return;
    try {
      await TerminalChannels.method.invokeMethod<String>('close');
    } on PlatformException {
      // The session may already be gone; that is an acceptable outcome.
    }
    state.value = TerminalEngineState.idle;
  }

  /// Closes the session and starts a fresh one.
  Future<void> restart() async {
    if (!_supported) return;
    await close();
    await start();
  }

  /// Releases stream resources; primarily for tests.
  Future<void> dispose() async {
    await _outputSubscription?.cancel();
    _outputSubscription = null;
  }

  void _subscribe() {
    unawaited(_outputSubscription?.cancel());
    _outputSubscription =
        TerminalChannels.output.receiveBroadcastStream().listen(
              _handleEvent,
              onError: _handleStreamError,
              cancelOnError: false,
            );
  }

  void _handleEvent(Object? event) {
    if (event is Map) {
      switch (event['type']) {
        case 'data':
          _append(OutputEntry(event['data']?.toString() ?? ''));
        case 'exit':
          final code = event['code'];
          _append(OutputEntry('* shell exited (exit code $code).',
              mergeable: false));
          state.value = TerminalEngineState.exited;
        default:
          break;
      }
    } else if (event is String && event.isNotEmpty) {
      _append(OutputEntry(event));
    }
  }

  void _handleStreamError(Object? error) {
    if (error is PlatformException) {
      state.value = TerminalEngineState.error;
      lastError.value = error.message ?? error.code;
      _append(OutputEntry('* stream error: ${error.message ?? error.code}',
          mergeable: false));
    }
  }

  void _append(TerminalEntry entry) {
    final current = List<TerminalEntry>.of(entries.value);
    final previous = current.isEmpty ? null : current.last;
    final canMerge = entry is OutputEntry &&
        entry.mergeable &&
        previous is OutputEntry &&
        previous.mergeable;
    if (canMerge) {
      // Merge consecutive streamed output (and partial lines) into one entry.
      current[current.length - 1] =
          OutputEntry('${previous.text}${entry.text}');
    } else {
      current.add(entry);
    }
    while (current.length > _maxEntries) {
      current.removeAt(0);
    }
    entries.value = current;
  }
}
