package com.cidevelop.robinhood_options_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.renderer.addIsDisplayingFlutterUiListener(object : FlutterUiDisplayListener {
            override fun onFlutterUiDisplayed() {
                // Once Flutter UI renders its first frame, clear the window background
                // so it does not remain in memory or flash behind any transparent routes.
                window.setBackgroundDrawable(null)
            }

            override fun onFlutterUiNoLongerDisplayed() {}
        })
    }
}
