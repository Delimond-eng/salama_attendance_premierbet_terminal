package com.salama_drc.terminal;

import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.view.View;

public class MdmKioskManager {
    private static final String PREFS_NAME = "mdm_prefs";
    private static final String KEY_KIOSK_ENABLED = "kiosk_enabled";
    
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
        if (!isDeviceOwner()) return false;

        try {
            // Set as home intent receiver
            // dpm.addPersistentPreferredActivity(adminName, intentFilter, componentName); // Optional: if we want to be the only launcher

            // Allow only this package to lock task
            dpm.setLockTaskPackages(adminName, new String[]{context.getPackageName()});
            
            // Disable keyguard and status bar (best effort)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setKeyguardDisabled(adminName, true);
                dpm.setStatusBarDisabled(adminName, true);
            }

            setKioskEnabled(true);
            activity.startLockTask();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public boolean disableKiosk(Activity activity) {
        if (!isDeviceOwner()) return false;

        try {
            activity.stopLockTask();
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setKeyguardDisabled(adminName, false);
                dpm.setStatusBarDisabled(adminName, false);
            }
            
            setKioskEnabled(false);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    public void setupImmersiveMode(Activity activity) {
        if (!isKioskEnabled()) return;
        
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
