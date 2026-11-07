import 'package:flutter/material.dart';

import 'services/terminal_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstraTermApp());
}

class AstraTermApp extends StatelessWidget {
  const AstraTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstraTerm',
      debugShowCheckedModeBanner: false,
      theme: AstraTermTheme.dark(),
      home: const TerminalHomePage(),
    );
  }
}

abstract final class AstraTermTheme {
  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF121A2B);
  static const elevated = Color(0xFF1A263B);
  static const accent = Color(0xFF69D9FF);
  static const green = Color(0xFF7BE0B2);
  static const muted = Color(0xFF91A0B8);
  static const danger = Color(0xFFF08C8C);
  static const amber = Color(0xFFF2C973);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class TerminalHomePage extends StatefulWidget {
  const TerminalHomePage({super.key});

  @override
  State<TerminalHomePage> createState() => _TerminalHomePageState();
}

class _TerminalHomePageState extends State<TerminalHomePage> {
  final TerminalShellService _service = TerminalShellService();
  late final ScrollController _consoleScrollController;

  @override
  void initState() {
    super.initState();
    _consoleScrollController = ScrollController();
    // Keep the console pinned to the newest streamed output.
    _service.entries.addListener(_scrollToLatestOutput);
    if (_service.isSupported) {
      _service.start();
    }
  }

  @override
  void dispose() {
    _service.entries.removeListener(_scrollToLatestOutput);
    _consoleScrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _scrollToLatestOutput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_consoleScrollController.hasClients) return;
      _consoleScrollController.jumpTo(
        _consoleScrollController.position.maxScrollExtent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported = _service.isSupported;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, color: AstraTermTheme.accent),
            SizedBox(width: 10),
            Text(
              'AstraTerm',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: supported
                ? 'Close and restart the shell session'
                : 'Shell session unavailable on this platform',
            onPressed: supported ? () => _service.restart() : null,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusStrip(service: _service),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF080D18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: _TerminalConsole(
                    service: _service,
                    scrollController: _consoleScrollController,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _CommandComposer(service: _service),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.service});

  final TerminalShellService service;

  static Color _stateColor(TerminalEngineState state) {
    return switch (state) {
      TerminalEngineState.connected => AstraTermTheme.green,
      TerminalEngineState.starting ||
      TerminalEngineState.idle ||
      TerminalEngineState.exited =>
        AstraTermTheme.amber,
      TerminalEngineState.error ||
      TerminalEngineState.unsupported =>
        AstraTermTheme.danger,
    };
  }

  static String _stateLabel(TerminalEngineState state) {
    return switch (state) {
      TerminalEngineState.idle => 'ENGINE IDLE',
      TerminalEngineState.starting => 'CONNECTING',
      TerminalEngineState.connected => 'CONNECTED',
      TerminalEngineState.exited => 'SESSION ENDED',
      TerminalEngineState.error => 'ENGINE ERROR',
      TerminalEngineState.unsupported => 'NOT SUPPORTED',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TerminalEngineState>(
      valueListenable: service.state,
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AstraTermTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 9, color: _stateColor(state)),
                  const SizedBox(width: 9),
                  const Text('LOCAL SHELL'),
                  const Spacer(),
                  Text(
                    _stateLabel(state),
                    style: const TextStyle(
                      color: AstraTermTheme.muted,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (service.lastError.value != null) ...[
                const SizedBox(height: 6),
                Text(
                  service.lastError.value!,
                  style: const TextStyle(
                    color: AstraTermTheme.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TerminalConsole extends StatelessWidget {
  const _TerminalConsole({
    required this.service,
    required this.scrollController,
  });

  final TerminalShellService service;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TerminalEntry>>(
      valueListenable: service.entries,
      builder: (context, entryList, _) {
        if (entryList.isEmpty) {
          return _TerminalWelcome(
            state: service.state.value,
            supported: service.isSupported,
          );
        }
        return ListView.builder(
          controller: scrollController,
          itemCount: entryList.length,
          itemBuilder: (context, index) {
            final entry = entryList[index];
            return switch (entry) {
              CommandEntry() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('❯ ',
                          style: TextStyle(color: AstraTermTheme.accent)),
                      Expanded(
                        child: Text(
                          entry.command,
                          style:
                              const TextStyle(color: Colors.white, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              OutputEntry() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: SelectableText(
                    entry.text,
                    style: const TextStyle(color: Colors.white, height: 1.45),
                  ),
                ),
            };
          },
        );
      },
    );
  }
}

class _TerminalWelcome extends StatelessWidget {
  const _TerminalWelcome({
    required this.state,
    required this.supported,
  });

  final TerminalEngineState state;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final engineLine = switch (state) {
      TerminalEngineState.unsupported ||
      TerminalEngineState.error when !supported =>
        'Execution engine: unavailable on this platform',
      _ => 'Execution engine: connecting to /system/bin/sh',
    };
    final body = supported
        ? 'Submit commands with the composer below. '
            'Output streams live from the Android system shell.'
        : 'The Android shell engine only runs on Android builds built from '
            'this repository. Desktop and iOS targets show this message.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AstraTerm terminal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const _TerminalLine(
          prompt: 'astra',
          command: 'phase 2.1',
          color: AstraTermTheme.green,
        ),
        const SizedBox(height: 12),
        const Text(
          'Phase 2.1 connects AstraTerm to the Android system shell '
          '(/system/bin/sh) inside the app sandbox.',
          style: TextStyle(color: Colors.white, height: 1.6),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(color: AstraTermTheme.muted, height: 1.6),
        ),
        const SizedBox(height: 18),
        Text(
          engineLine,
          style: const TextStyle(color: AstraTermTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        const Text(
          'No PTY, BusyBox, package manager or Debian/Ubuntu userspace yet.',
          style: TextStyle(color: AstraTermTheme.muted, fontSize: 12),
        ),
        const Spacer(),
        const Text(
          'AstraTerm • Universal terminal project',
          style: TextStyle(color: AstraTermTheme.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.prompt,
    required this.command,
    required this.color,
  });

  final String prompt;
  final String command;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$prompt ', style: TextStyle(color: color)),
        const Text('~ ', style: TextStyle(color: AstraTermTheme.muted)),
        Text(command, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _CommandComposer extends StatefulWidget {
  const _CommandComposer({required this.service});

  final TerminalShellService service;

  @override
  State<_CommandComposer> createState() => _CommandComposerState();
}

class _CommandComposerState extends State<_CommandComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final command = _controller.text;
    if (command.trim().isEmpty) return;

    if (!widget.service.isSupported) return;
    // Auto-start a session when the first command is submitted while idle.
    if (widget.service.state.value == TerminalEngineState.idle ||
        widget.service.state.value == TerminalEngineState.exited) {
      await widget.service.start();
    }
    await widget.service.write(command);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TerminalEngineState>(
      valueListenable: widget.service.state,
      builder: (context, state, _) {
        final enabled = widget.service.isSupported;
        final canSubmit = enabled && _controller.text.trim().isNotEmpty;
        return TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: enabled,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: enabled
                ? 'Enter a shell command for /system/bin/sh'
                : 'Android shell is unavailable on this platform',
            prefixIcon: const Icon(Icons.chevron_right_rounded),
            suffixIcon: IconButton(
              onPressed: canSubmit ? _submit : null,
              tooltip: 'Execute',
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        );
      },
    );
  }
}
