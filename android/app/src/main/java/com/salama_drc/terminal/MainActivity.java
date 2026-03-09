package com.salama_drc.terminal;

import android.os.Bundle;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "salama/terminal_native";
    private static final String TAG = "MainActivityMDM";
    private MdmKioskManager kioskManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        kioskManager = new MdmKioskManager(this);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "enableMdmKiosk":
                            result.success(kioskManager.enableKiosk(this));
                            break;
                        case "disableMdmKiosk":
                            result.success(kioskManager.disableKiosk(this));
                            break;
                        case "isMdmKioskEnabled":
                            result.success(kioskManager.isKioskEnabled());
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (kioskManager != null && kioskManager.isKioskEnabled()) {
            kioskManager.setupImmersiveMode(this);
            try {
                // Force lock task mode if enabled and Device Owner
                if (kioskManager.isDeviceOwner()) {
                    startLockTask();
                    Log.d(TAG, "Lock Task Mode Started");
                }
            } catch (Exception e) {
                Log.e(TAG, "Error starting lock task: " + e.getMessage());
            }
        }
    }
}
