package com.salama_drc.terminal;

import android.view.KeyEvent;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;

public class MainActivity extends FlutterActivity {
    private static final String VOLUME_KEY_CHANNEL = "salama/volume_keys";
    private EventChannel.EventSink volumeKeySink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                VOLUME_KEY_CHANNEL
        ).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                volumeKeySink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                volumeKeySink = null;
            }
        });
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP && volumeKeySink != null) {
            volumeKeySink.success("volume_up");
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }
}
