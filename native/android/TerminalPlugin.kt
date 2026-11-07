package com.astra.term

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Phase 2.1 Android shell engine.
 *
 * A minimal, sandboxed adapter around Android's system shell ("/system/bin/sh").
 * It is intentionally NOT a full Linux environment: there is no PTY, no
 * BusyBox, no package manager and no Debian/Ubuntu userspace in this milestone.
 * Root privileges are never requested or used.
 *
 * Session gating: every successful [startShell] gets a monotonically
 * increasing session id that is echoed in start results and every streamed
 * event. Readers/failure notifications from a retired session are dropped,
 * so stale events can never leak into a restarted session. Intentional
 * shutdowns (explicit "close" or engine teardown) suppress the natural-exit
 * event because Flutter has already left the session intentionally.
 *
 * Channel contracts (used from Dart):
 *  - MethodChannel "com.astra.term/terminal" -> methods: start, write, close
 *      start -> {"status": "started"|"already_running", "session": <long>}
 *      write -> "written"  (argument "command": String)
 *      close -> "closed"
 *  - EventChannel "com.astra.term/terminal_output" -> events:
 *      {"type": "data", "session": <long>, "data": <merged stdout/stderr chunk>}
 *      {"type": "exit", "session": <long>, "code": <int process exit code>}
 */
class TerminalPlugin(context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.astra.term/terminal"
        const val EVENT_CHANNEL_NAME = "com.astra.term/terminal_output"
        private const val TAG = "AstraTerminal"
        private const val SYSTEM_SHELL = "/system/bin/sh"
    }

    private val appContext: Context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private var shellProcess: Process? = null
    private var shellWriter: BufferedWriter? = null
    private var readerThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    private val pendingOutput = StringBuilder()
    private val running = AtomicBoolean(false)
    private val currentSession = AtomicLong(0)
    private val intentionalClose = AtomicBoolean(false)

    /** Registers the method and event channels on the Flutter engine. */
    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
            .setMethodCallHandler(this)
        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
            .setStreamHandler(this)
    }

    /** Tears the shell down safely when the Flutter engine is destroyed.
     *  Treated like an explicit close: no natural-exit event is emitted. */
    fun detach() {
        closeShell()
        mainHandler.post {
            val sink = eventSink
            eventSink = null
            try {
                sink?.endOfStream()
            } catch (e: IllegalStateException) {
                Log.w(TAG, "endOfStream rejected after teardown: ${e.message}")
            }
        }
    }

    // ------------------------------------------------------------------
    // MethodChannel: start / write / close
    // ------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startShell(result)
            "write" -> {
                val command = call.argument<String>("command")
                if (command.isNullOrEmpty()) {
                    result.error("invalid_argument", "Missing command payload.", null)
                    return
                }
                writeToShell(command, result)
            }
            "close" -> {
                closeShell()
                result.success("closed")
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Launches the persistent system shell. Duplicate shells are prevented:
     * a live session is reported instead of spawning a second process.
     */
    private fun startShell(result: MethodChannel.Result) {
        if (running.get() && isProcessAlive()) {
            result.success(
                mapOf("status" to "already_running", "session" to currentSession.get())
            )
            return
        }
        if (running.get()) {
            // The previous session died on its own; retire it silently.
            closeShell()
        }
        try {
            val home = File(appContext.filesDir, "home").apply { mkdirs() }
            val tmpDir = File(appContext.cacheDir, "tmp").apply { mkdirs() }

            val builder = ProcessBuilder(SYSTEM_SHELL)
            builder.redirectErrorStream(true) // merge stderr into stdout
            val env = builder.environment()
            env["HOME"] = home.absolutePath
            env["TMPDIR"] = tmpDir.absolutePath
            env["PATH"] = listOf(
                "${home.absolutePath}/bin",
                "${home.absolutePath}/usr/bin",
                "/apex/com.android.runtime/bin",
                "/apex/com.android.art/bin",
                "/system/bin",
                "/system/xbin",
                "/system/usr/bin",
            ).joinToString(":")
            env["TERM"] = "dumb" // no PTY support in this milestone
            env["LANG"] = "C.UTF-8"

            val process = builder.start()
            val session = currentSession.incrementAndGet()
            shellProcess = process
            shellWriter =
                BufferedWriter(OutputStreamWriter(process.outputStream, Charsets.UTF_8))
            running.set(true)
            intentionalClose.set(false)
            startReader(process, session)
            result.success(mapOf("status" to "started", "session" to session))
        } catch (e: IOException) {
            closeShell()
            result.error(
                "spawn_failed",
                "Unable to launch $SYSTEM_SHELL: ${e.message}",
                null,
            )
        }
    }

    private fun writeToShell(command: String, result: MethodChannel.Result) {
        val writer = shellWriter
        if (!running.get() || writer == null || !isProcessAlive()) {
            result.error(
                "not_running",
                "The shell session is not running. Start a session first.",
                null,
            )
            return
        }
        try {
            writer.write(command)
            writer.newLine()
            writer.flush()
            result.success("written")
        } catch (e: IOException) {
            closeShell()
            result.error(
                "write_failed",
                "Failed to write to the shell session: ${e.message}",
                null,
            )
        }
    }

    // ------------------------------------------------------------------
    // Output streaming
    // ------------------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val buffered: String
        val sessionAtDrain: Long
        synchronized(pendingOutput) {
            buffered = pendingOutput.toString()
            pendingOutput.setLength(0)
            sessionAtDrain = currentSession.get()
        }
        if (buffered.isNotEmpty()) {
            events?.success(
                mapOf("type" to "data", "session" to sessionAtDrain, "data" to buffered)
            )
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * Reads the merged stdout/stderr stream and forwards session-gated chunks
     * to Flutter. Runs on its own worker thread so nothing here can block the
     * Android main thread. Output belonging to a retired session is dropped
     * before it is ever buffered.
     */
    private fun startReader(process: Process, session: Long) {
        val thread = Thread {
            try {
                val reader =
                    BufferedReader(InputStreamReader(process.inputStream, Charsets.UTF_8), 8192)
                val buffer = CharArray(4096)
                while (true) {
                    val read = reader.read(buffer, 0, buffer.size)
                    if (read < 0) break
                    val chunk = String(buffer, 0, read)
                    var queued = false
                    synchronized(pendingOutput) {
                        // CURRENT session only: after closeShell() retires the
                        // session id, a lingering reader cannot buffer or
                        // schedule anything for it.
                        if (running.get() && currentSession.get() == session) {
                            pendingOutput.append(chunk)
                            queued = true
                        }
                    }
                    if (queued) {
                        mainHandler.post { drainPendingOutput(session) }
                    }
                }
            } catch (e: IOException) {
                // Stream closed by teardown or a crashed process; the exit
                // handler below still runs once waitFor() completes.
                Log.w(TAG, "Shell output stream ended: ${e.message}")
            }
            val code = try {
                process.waitFor()
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                -1
            }
            notifyExit(session, code)
        }
        thread.name = "astra-shell-reader"
        thread.isDaemon = true
        readerThread = thread
        thread.start()
    }

    /**
     * Must run on the Android main thread: EventSink is main-thread only.
     * Emits buffered output only while the session id still matches the
     * active session; anything left over from a retired session is discarded
     * and can never reach Flutter.
     */
    private fun drainPendingOutput(session: Long) {
        val sink = eventSink
        if (sink == null) {
            return
        }
        if (currentSession.get() != session) {
            synchronized(pendingOutput) { pendingOutput.setLength(0) }
            return
        }
        val chunk: String
        synchronized(pendingOutput) {
            chunk = pendingOutput.toString()
            pendingOutput.setLength(0)
        }
        if (chunk.isEmpty()) {
            return
        }
        try {
            sink.success(mapOf("type" to "data", "session" to session, "data" to chunk))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to emit shell output: ${e.message}")
        }
    }

    /**
     * Runs when the reader observed the process exit. Posted on the main
     * thread, non-blocking, and gated on the session id: stale notifications
     * from retired sessions are dropped, and an intentional shutdown never
     * emits an exit event (Flutter already moved to its idle state).
     */
    private fun notifyExit(session: Long, code: Int) {
        mainHandler.post {
            if (currentSession.get() != session) {
                Log.i(TAG, "Dropping exit notification for retired session $session")
                return@post
            }
            // Flush any trailing output belonging to this (still active) session.
            drainPendingOutput(session)
            running.set(false)
            val sink = eventSink
            if (intentionalClose.get()) {
                Log.i(TAG, "Session $session closed intentionally; exit suppressed")
                return@post
            }
            eventSink = null
            if (sink == null) {
                return@post
            }
            try {
                sink.success(mapOf("type" to "exit", "session" to session, "code" to code))
                sink.endOfStream()
            } catch (e: IllegalStateException) {
                Log.w(TAG, "Exit event rejected: ${e.message}")
            }
        }
    }

    // ------------------------------------------------------------------
    // Cleanup
    // ------------------------------------------------------------------

    /**
     * Liveness via [Process.exitValue]: the documented helper throws
     * [IllegalThreadStateException] while the process is still running.
     * All other return paths mean the process has exited.
     */
    private fun isProcessAlive(): Boolean {
        val process = shellProcess ?: return false
        return try {
            process.exitValue()
            false
        } catch (e: IllegalThreadStateException) {
            true
        }
    }

    /**
     * Retires the current session and tears the shell down without blocking:
     * destroy() is asynchronous, the reader's waitFor() lives on the reader
     * thread, and no caller ever joins it.
     */
    private fun closeShell() {
        val retiredSession = currentSession.get()
        // Retire the session id first: a still-running reader thread will stop
        // buffering/scheduling data for it, and any pending exit notification
        // becomes stale no matter what killed the process.
        currentSession.incrementAndGet()
        running.set(false)
        intentionalClose.set(true)
        try {
            shellWriter?.close()
        } catch (e: IOException) {
            // Stream close failure no longer matters during teardown.
        }
        shellWriter = null
        synchronized(pendingOutput) {
            // Never let content of the retired session leak into a new one.
            pendingOutput.setLength(0)
        }
        try {
            shellProcess?.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "Shell destroy failed: ${e.message}")
        }
        shellProcess = null
        readerThread = null
        Log.i(TAG, "Shell session $retiredSession retired and torn down")
    }
}
