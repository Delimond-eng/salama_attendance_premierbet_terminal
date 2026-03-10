package com.salama_drc.terminal;

import android.app.ActivityManager;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "Terminal-MainActivity";
    private static final String CHANNEL = "salama/terminal_native";
    private MdmKioskManager kioskManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Préparation de l'écran pour un usage Kiosque (Toujours allumé, pas de lock screen)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        }
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON 
                | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED 
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);

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
    public boolean dispatchKeyEvent(KeyEvent event) {
        // Bloquer les touches physiques si le mode Kiosque est actif
        if (kioskManager.isKioskEnabled()) {
            int keyCode = event.getKeyCode();
            if (keyCode == KeyEvent.KEYCODE_BACK || 
                keyCode == KeyEvent.KEYCODE_HOME ||
                keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
                return true; 
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (kioskManager != null && kioskManager.isKioskEnabled()) {
            kioskManager.setupImmersiveMode(this);
            if (kioskManager.isDeviceOwner()) {
                try {
                    ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && am.getLockTaskModeState() == ActivityManager.LOCK_TASK_MODE_NONE) {
                        startLockTask();
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Fail to start LockTask", e);
                }
            }
        }
    }
}
