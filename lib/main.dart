import 'package:flutter/material.dart';

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

class TerminalHomePage extends StatelessWidget {
  const TerminalHomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'New session (coming soon)',
            onPressed: null,
            icon: const Icon(Icons.add_rounded),
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
              const _StatusStrip(),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF080D18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const _TerminalWelcome(),
                ),
              ),
              const SizedBox(height: 14),
              const _CommandComposer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AstraTermTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, size: 9, color: AstraTermTheme.green),
          SizedBox(width: 9),
          Text('LOCAL WORKSPACE'),
          Spacer(),
          Text(
            'PHASE 1',
            style: TextStyle(
              color: AstraTermTheme.muted,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalWelcome extends StatelessWidget {
  const _TerminalWelcome();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AstraTerm terminal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 18),
        _TerminalLine(
          prompt: 'astra',
          command: 'welcome',
          color: AstraTermTheme.green,
        ),
        SizedBox(height: 12),
        Text(
          'Welcome to AstraTerm.',
          style: TextStyle(color: Colors.white, height: 1.6),
        ),
        Text(
          'The shared application foundation is ready.',
          style: TextStyle(color: AstraTermTheme.muted, height: 1.6),
        ),
        SizedBox(height: 18),
        Text(
          'Execution engine: not connected',
          style: TextStyle(color: AstraTermTheme.muted, fontSize: 12),
        ),
        SizedBox(height: 6),
        Text(
          'A real shell/PTY backend will be added in the next milestone.',
          style: TextStyle(color: AstraTermTheme.muted, fontSize: 12),
        ),
        Spacer(),
        Text(
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

class _CommandComposer extends StatelessWidget {
  const _CommandComposer();

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: false,
      decoration: InputDecoration(
        hintText: 'Terminal execution will be enabled in Phase 2',
        prefixIcon: const Icon(Icons.chevron_right_rounded),
        suffixIcon: IconButton(
          onPressed: null,
          tooltip: 'Execute',
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
    );
  }
}
