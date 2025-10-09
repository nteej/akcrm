package fi.finnerp.erp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import id.flutter.flutter_background_service.BackgroundService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device boot completed")

            // Check if there was an active job before reboot
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )

            val isTracking = prefs.getBoolean("flutter.is_tracking", false)
            // Use getLong because Dart SharedPreferences stores int as Long
            val jobId = prefs.getLong("flutter.tracking_job_id", -1L).toInt()

            Log.d("BootReceiver", "isTracking: $isTracking, jobId: $jobId")

            if (isTracking && jobId != -1) {
                Log.d("BootReceiver", "Restarting location tracking service for job $jobId")

                // Restart the background service
                try {
                    val serviceIntent = Intent(context, BackgroundService::class.java)
                    context.startForegroundService(serviceIntent)
                    Log.d("BootReceiver", "Background service restarted successfully")
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Failed to restart background service: ${e.message}")
                }
            } else {
                Log.d("BootReceiver", "No active tracking job found, not starting service")
            }
        }
    }
}
