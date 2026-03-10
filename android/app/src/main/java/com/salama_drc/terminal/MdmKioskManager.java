package com.salama_drc.terminal;

import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.os.Build;
import android.view.View;
import android.util.Log;

public class MdmKioskManager {
    private static final String PREFS_NAME = "mdm_prefs";
    private static final String KEY_KIOSK_ENABLED = "kiosk_enabled";
    private static final String TAG = "MdmKioskManager";
    
    private final Context context;
    private final DevicePolicyManager dpm;
    private final ComponentName adminName;

    public MdmKioskManager(Context context) {
        this.context = context;
        this.dpm = (DevicePolicyManager) context.getSystemService(Context.DEVICE_POLICY_SERVICE);
        this.adminName = new ComponentName(context, MdmDeviceAdminReceiver.class);
    }

    public boolean isDeviceOwner() {
        return dpm.isDeviceOwnerApp(context.getPackageName());
    }

    public boolean isKioskEnabled() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean(KEY_KIOSK_ENABLED, false);
    }

    public void setKioskEnabled(boolean enabled) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putBoolean(KEY_KIOSK_ENABLED, enabled).apply();
    }

    public boolean enableKiosk(Activity activity) {
        if (!isDeviceOwner()) {
            Log.e(TAG, "Not Device Owner. Cannot enable Kiosk.");
            return false;
        }

        try {
            // 1. Whitelist for Lock Task
            dpm.setLockTaskPackages(adminName, new String[]{context.getPackageName()});
            
            // 2. Set as Default Launcher (IMPORTANT for Boot auto-launch)
            IntentFilter intentFilter = new IntentFilter(Intent.ACTION_MAIN);
            intentFilter.addCategory(Intent.CATEGORY_HOME);
            intentFilter.addCategory(Intent.CATEGORY_DEFAULT);
            dpm.addPersistentPreferredActivity(adminName, intentFilter, new ComponentName(context.getPackageName(), MainActivity.class.getName()));

            // 3. Android 11+ security features
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                dpm.setLockTaskFeatures(adminName, DevicePolicyManager.LOCK_TASK_FEATURE_NONE);
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setKeyguardDisabled(adminName, true);
                dpm.setStatusBarDisabled(adminName, true);
            }

            setKioskEnabled(true);
            activity.startLockTask();
            setupImmersiveMode(activity);
            
            Log.d(TAG, "Kiosk mode ENABLED and set as HOME");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to enable kiosk: " + e.getMessage());
            return false;
        }
    }

    public boolean disableKiosk(Activity activity) {
        try {
            // Remove as Default Launcher
            dpm.clearPackagePersistentPreferredActivities(adminName, context.getPackageName());
            
            activity.stopLockTask();
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setKeyguardDisabled(adminName, false);
                dpm.setStatusBarDisabled(adminName, false);
            }
            
            setKioskEnabled(false);
            Log.d(TAG, "Kiosk mode DISABLED");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Failed to disable kiosk: " + e.getMessage());
            return false;
        }
    }

    public void setupImmersiveMode(Activity activity) {
        View decorView = activity.getWindow().getDecorView();
        decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }
}
