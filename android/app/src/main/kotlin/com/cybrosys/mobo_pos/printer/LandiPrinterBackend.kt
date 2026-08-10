package com.cybrosys.mobo_pos.printer

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import com.sdksuite.omnidriver.OmniConnection
import com.sdksuite.omnidriver.OmniDriver
import com.sdksuite.omnidriver.aidl.printer.Align
import com.sdksuite.omnidriver.aidl.printer.BaseOption
import com.sdksuite.omnidriver.aidl.printer.TextStyle
import com.sdksuite.omnidriver.api.CanvasPrinter
import com.sdksuite.omnidriver.api.OnPrintListener
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Built-in thermal printer for the Landi M20, driven through the SDK-Suite
 * "xsuite" OmniDriver (`com.sdksuite.omnidriver`), binding the on-device
 * `com.sdksuite.omnidriver/.OmniDriverService`.
 *
 * The receipt arrives as newline-separated text. We print via the CanvasPrinter
 * text API: [CanvasPrinter.renderText] per line (the SDK rasterizes with the
 * device font + darkness — more reliable than pushing a bitmap), then
 * [CanvasPrinter.startPrint].
 *
 * Connection is async: [OmniDriver.init] binds the service and fires
 * [OmniConnection.onConnected]; [isAvailable] reflects that.
 */
class LandiPrinterBackend : PrinterBackend {

    private var driver: OmniDriver? = null
    @Volatile private var connected = false

    override fun init(context: Context) {
        try {
            val d = OmniDriver.me(context.applicationContext)
            d.init(object : OmniConnection {
                override fun onConnected() {
                    connected = true
                    Log.i(TAG, "OmniDriver connected (v=${runCatching { d.getVersion() }.getOrNull()})")
                }

                override fun onDisconnected(reason: Int) {
                    connected = false
                    Log.w(TAG, "OmniDriver disconnected: $reason")
                }
            })
            driver = d
            Log.i(TAG, "OmniDriver init requested")
        } catch (t: Throwable) {
            connected = false
            Log.w(TAG, "OmniDriver init failed: ${t.javaClass.simpleName}: ${t.message}", t)
        }
    }

    override fun isAvailable(): Boolean = connected

    override fun printText(text: String, paperWidthMm: Int): Boolean {
        val d = driver
        if (d == null || !connected) {
            Log.w(TAG, "printer not connected (driver=${d != null}, connected=$connected)")
            return false
        }
        var printer: CanvasPrinter? = null
        return try {
            printer = d.getCanvasPrinter(Bundle())
            printer.openDevice(0)

            val width = if (paperWidthMm >= 80) 576 else 384
            val lines = if (text.isBlank()) listOf(" ") else text.split("\n")
            val canvasHeight = lines.size * LINE_HEIGHT + 24

            printer.init(BaseOption(width, canvasHeight, PRINT_GRAY))
            Log.i(
                TAG,
                "canvas status=${runCatching { printer.getStatus() }.getOrNull()} " +
                    "w=$width h=$canvasHeight lines=${lines.size} gray=$PRINT_GRAY"
            )

            var y = 0
            for (line in lines) {
                val style = TextStyle(
                    /* typefaceName   */ "",
                    /* typefacePath   */ "",
                    /* fontSize       */ FONT_SIZE,
                    /* letterSpace    */ 0f,
                    /* textColor      */ Color.BLACK,
                    /* isStrikeThrough*/ false,
                    /* isBold         */ true,
                    /* isItalic       */ false,
                    /* isUnderline    */ false,
                    /* scaleX         */ 1f,
                    /* scaleY         */ 1f,
                    /* pointX         */ 0,
                    /* pointY         */ y,
                    /* width          */ width,
                    /* height         */ LINE_HEIGHT,
                    /* align          */ Align.LEFT,
                    /* rotation       */ 0,
                )
                printer.renderText(if (line.isEmpty()) " " else line, style)
                y += LINE_HEIGHT
            }

            val latch = CountDownLatch(1)
            val ok = booleanArrayOf(false)
            printer.startPrint(object : OnPrintListener {
                override fun onSuccess() {
                    ok[0] = true
                    latch.countDown()
                }

                override fun onFail(error: Int) {
                    Log.e(TAG, "print onFail: $error")
                    latch.countDown()
                }
            })
            val completed = latch.await(20, TimeUnit.SECONDS)
            Log.i(TAG, "print completed=$completed success=${ok[0]}")
            completed && ok[0]
        } catch (t: Throwable) {
            Log.e(TAG, "print failed: ${t.javaClass.simpleName}: ${t.message}", t)
            false
        } finally {
            runCatching { printer?.closeDevice() }
        }
    }

    override fun dispose() {
        runCatching { driver?.destroy() }
        driver = null
        connected = false
    }

    companion object {
        private const val TAG = "MoboPrinter"

        /** Print darkness/heat for BaseOption. 0 = blank; higher = darker.
         *  8 produced nothing on this head, so raise well up. If it comes out
         *  too dark or onFail=PRINTER_OVER_HEAT, lower it. */
        private const val PRINT_GRAY = 80

        /** TrueType font size (px) and per-line height on the canvas. */
        private const val FONT_SIZE = 22
        private const val LINE_HEIGHT = 28
    }
}
