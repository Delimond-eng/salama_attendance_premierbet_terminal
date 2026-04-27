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
import android.view.WindowInsets;
import android.view.WindowInsetsController;

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
        if (!isDeviceOwner()) return false;

        try {
            dpm.setLockTaskPackages(adminName, new String[]{context.getPackageName()});
            
            IntentFilter filter = new IntentFilter(Intent.ACTION_MAIN);
            filter.addCategory(Intent.CATEGORY_HOME);
            filter.addCategory(Intent.CATEGORY_DEFAULT);
            dpm.clearPackagePersistentPreferredActivities(adminName, context.getPackageName());
            dpm.addPersistentPreferredActivity(adminName, filter, new ComponentName(context.getPackageName(), MainActivity.class.getName()));

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Autorise le bouton Power (GLOBAL_ACTIONS) et la Keyguard (si désiré)
                // On active LOCK_TASK_FEATURE_GLOBAL_ACTIONS pour permettre d'éteindre/redémarrer
                dpm.setLockTaskFeatures(adminName, DevicePolicyManager.LOCK_TASK_FEATURE_GLOBAL_ACTIONS);
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // On ne désactive pas forcément la keyguard si on veut permettre le verrouillage power
                // Mais pour un kiosk pur, on la laisse désactivée.
                dpm.setKeyguardDisabled(adminName, true);
                dpm.setStatusBarDisabled(adminName, true);
            }

            setKioskEnabled(true);
            activity.startLockTask();
            setupImmersiveMode(activity);
            
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error: " + e.getMessage());
            return false;
        }
    }

    public boolean disableKiosk(Activity activity) {
        try {
            dpm.clearPackagePersistentPreferredActivities(adminName, context.getPackageName());
            activity.stopLockTask();
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setKeyguardDisabled(adminName, false);
                dpm.setStatusBarDisabled(adminName, false);
            }
            
            setKioskEnabled(false);
            
            // Restore System UI
            View decorView = activity.getWindow().getDecorView();
            decorView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
            
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public void setupImmersiveMode(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30) masquage forcé
            final WindowInsetsController controller = activity.getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            // Anciennes versions
            View decorView = activity.getWindow().getDecorView();
            decorView.setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    | View.SYSTEM_UI_FLAG_FULLSCREEN);
        }
    }
}
