package io.github.rktuhinbd.presencelens.attendance

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceRoute
import io.github.rktuhinbd.presencelens.attendance.ui.theme.PresenceLensAttendanceTheme

/**
 * Single-screen host. It holds no location logic, no permission logic and no state of its own
 * - those live in `data` and `presentation` respectively, which is what keeps them testable.
 *
 * The back affordance in the app bar finishes the Activity: the assessment specifies one
 * screen (AND-04), so there is nothing to navigate back to inside the app.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PresenceLensAttendanceTheme {
                AttendanceRoute(
                    modifier = Modifier.fillMaxSize(),
                    onNavigateBack = { finish() }
                )
            }
        }
    }
}
