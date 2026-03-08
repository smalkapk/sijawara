package com.smalka.sijawara

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val CHANNEL = "sijawara/launch_actions"
		private const val PREFS_NAME = "sijawara_launch_actions"
		private const val KEY_PENDING_ACTION = "pending_action"
		private const val EXTRA_LAUNCH_ACTION = "launch_action"
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		cacheLaunchAction(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		cacheLaunchAction(intent)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getAndClearPendingAction" -> {
						val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
						val action = prefs.getString(KEY_PENDING_ACTION, null)
						prefs.edit().remove(KEY_PENDING_ACTION).apply()
						result.success(action)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun cacheLaunchAction(intent: Intent?) {
		val action = intent?.getStringExtra(EXTRA_LAUNCH_ACTION)
			?: intent?.data?.lastPathSegment

		if (action.isNullOrBlank()) return

		getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
			.edit()
			.putString(KEY_PENDING_ACTION, action)
			.apply()
	}
}
