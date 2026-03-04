package com.salama_drc.terminal;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "salama/terminal_native";
    private static final int LOCATION_PERMISSION_REQUEST_CODE = 1001;
    private MdmKioskManager kioskManager;
    private MethodChannel.Result pendingResult;
    private LocationManager locationManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        kioskManager = new MdmKioskManager(this);
        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
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
                        case "getTerminalLocation":
                            this.pendingResult = result;
                            requestLocationUpdate();
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void requestLocationUpdate() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, 
                new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 
                LOCATION_PERMISSION_REQUEST_CODE);
            return;
        }

        // Pour un terminal mobile, on demande une mise à jour fraîche (pas le cache)
        String provider = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) 
            ? LocationManager.GPS_PROVIDER 
            : LocationManager.NETWORK_PROVIDER;

        locationManager.requestSingleUpdate(provider, new LocationListener() {
            @Override
            public void onLocationChanged(@NonNull Location location) {
                if (pendingResult != null) {
                    Map<String, Double> coordinates = new HashMap<>();
                    coordinates.put("latitude", location.getLatitude());
                    coordinates.put("longitude", location.getLongitude());
                    pendingResult.success(coordinates);
                    pendingResult = null;
                }
            }
            @Override public void onStatusChanged(String provider, int status, Bundle extras) {}
            @Override public void onProviderEnabled(@NonNull String provider) {}
            @Override public void onProviderDisabled(@NonNull String provider) {}
        }, null);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                requestLocationUpdate();
            } else if (pendingResult != null) {
                pendingResult.error("PERMISSION_DENIED", "Permission refusée", null);
                pendingResult = null;
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (kioskManager != null && kioskManager.isKioskEnabled()) {
            kioskManager.setupImmersiveMode(this);
            try {
                startLockTask();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}
