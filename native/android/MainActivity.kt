package com.astra.term

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Custom MainActivity for AstraTerm (application ID com.astra.term).
 *
 * The generated placeholder from `flutter create` is replaced by the
 * bootstrap script with this implementation, which wires the Phase 2.1
 * Android shell engine into the Flutter engine and cleans it up on
 * activity destruction (safe against app lifecycle changes).
 */
class MainActivity : FlutterActivity() {

    private var terminalPlugin: TerminalPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        terminalPlugin = TerminalPlugin(applicationContext)
        terminalPlugin?.attach(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        terminalPlugin?.detach()
        terminalPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
