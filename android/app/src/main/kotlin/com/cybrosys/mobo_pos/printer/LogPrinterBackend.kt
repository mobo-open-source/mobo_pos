package com.cybrosys.mobo_pos.printer

import android.content.Context
import android.util.Log

/**
 * Fallback backend used when the NSDK printer isn't available (e.g. running on
 * an emulator). It prints nothing physically — it writes the receipt text to
 * logcat so the whole pipeline can still be exercised:
 *
 *   adb logcat -s MoboPrinter
 */
class LogPrinterBackend : PrinterBackend {

    override fun isAvailable(): Boolean = true

    override fun printText(text: String, paperWidthMm: Int): Boolean {
        Log.i(TAG, "---- RECEIPT (${paperWidthMm}mm) ----")
        text.split('\n').forEach { line -> Log.i(TAG, line) }
        Log.i(TAG, "---- END RECEIPT ----")
        return true
    }

    companion object {
        private const val TAG = "MoboPrinter"
    }
}
