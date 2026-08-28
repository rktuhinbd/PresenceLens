package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import java.text.DateFormat
import java.util.Date

/**
 * Renders the office capture time. Uses the platform's locale-aware short date/time format
 * rather than a hand-written pattern, so the line reads naturally wherever the device is set.
 */
object TimestampFormatter {

    fun format(epochMillis: Long): String =
        DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(epochMillis))
}
