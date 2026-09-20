package com.cybrosys.mobo_pos.printer

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Registers the `com.cybrosys.mobo_pos/printer` MethodChannel and routes calls
 * from the Dart [PrinterService] to the active [PrinterBackend].
 *
 * Backend selection: the real [LandiPrinterBackend] (Newland NSDK) is preferred;
 * when it is unavailable (e.g. an x86 emulator where the native lib can't load)
 * we fall back to [LogPrinterBackend], which decodes the receipt to logcat so
 * the whole pipeline can still be exercised.
 *
 * Printing runs on a background thread — [ESCPrinter.exec] is a blocking native
 * call — and the [MethodChannel.Result] is delivered back on the main thread.
 */
class PrinterChannel(context: Context) : MethodChannel.MethodCallHandler {

    // Both backends are created up front. The NSDK/OmniDriver connection is
    // ASYNC, so we must NOT pick a backend once at startup (it wouldn't be
    // connected yet). Instead choose per call: use the real printer whenever it
    // is connected, otherwise fall back to the logcat backend.
    private val landi = LandiPrinterBackend().apply { init(context) }
    private val logBackend = LogPrinterBackend().apply { init(context) }

    private fun active(): PrinterBackend =
        if (landi.isAvailable()) landi else logBackend

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "isBuiltinAvailable" -> result.success(landi.isAvailable())

            "printText" -> {
                val text = call.argument<String>("text")
                val paperWidth = call.argument<Int>("paperWidth") ?: 58
                if (text == null) {
                    result.error("BAD_ARGS", "Missing 'text'", null)
                    return
                }
                executor.execute {
                    val out: Result<Boolean> = try {
                        Result.success(active().printText(text, paperWidth))
                    } catch (e: Exception) {
                        Result.failure(e)
                    }
                    mainHandler.post {
                        out.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("PRINT_FAILED", it.message, null) },
                        )
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.cybrosys.mobo_pos/printer"
    }
}
