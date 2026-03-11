package au.com.marinesafe.app


import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "marine_safe/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPackageName" -> runOnUiThread {
                        result.success(applicationContext.packageName)
                    }
                    "getAndroidSdkInt" -> runOnUiThread {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    "openExactAlarmSettings" -> runOnUiThread {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                result.success(true)
                            } else {
                                openAppDetails(result)
                            }
                        } catch (e: Exception) {
                            openAppDetails(result)
                        }
                    }
                    "openAppDetails" -> runOnUiThread { openAppDetails(result) }
                    "openBatteryOptimizationSettings" -> runOnUiThread {
                        openBatteryOptimizationSettings(result)
                    }
                    "isIgnoringBatteryOptimizations" -> runOnUiThread {
                        try {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            val pkg = applicationContext.packageName
                            val ignoring = pm.isIgnoringBatteryOptimizations(pkg)
                            result.success(ignoring)
                        } catch (e: Exception) {
                            result.error("ERR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAppDetails(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:${applicationContext.packageName}")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERR", e.message, null)
        }
    }

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        try {
            val pkg = applicationContext.packageName
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$pkg")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(true)
            } catch (e2: Exception) {
                openAppDetails(result)
            }
        }
    }
}
