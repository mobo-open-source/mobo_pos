package com.cybrosys.mobo_pos.printer

import android.content.Context

/**
 * Contract for delivering a receipt to the device's built-in thermal printer.
 *
 * The Newland NSDK core prints bitmaps (not raw ESC/POS), so the contract is a
 * plain-text receipt: the Dart side sends the already-laid-out receipt text and
 * the backend renders it to a monochrome bitmap and prints it. This keeps the
 * pipeline independent of any single vendor's command set.
 */
interface PrinterBackend {
    /** Called once when the channel is created. */
    fun init(context: Context) {}

    /** True when a usable printer is present and initialised on this device. */
    fun isAvailable(): Boolean

    /**
     * Print [text] (a full, newline-separated receipt) on paper of
     * [paperWidthMm] (58 or 80). Returns true on success.
     */
    fun printText(text: String, paperWidthMm: Int): Boolean

    /** Release any bound resources. */
    fun dispose() {}
}
