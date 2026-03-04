package com.salama_drc.terminal;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
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
                        case "getTerminalLocation":
                            this.pendingResult = result;
                            getLocation();
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void getLocation() {
        // 1. Vérification et Demande d'autorisation si nécessaire
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, 
                new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION}, 
                LOCATION_PERMISSION_REQUEST_CODE);
            return;
        }

        // 2. Si déjà autorisé, on récupère la position
        LocationManager locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        Location lastKnownLocation = null;

        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            lastKnownLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER);
        }
        
        if (lastKnownLocation == null && locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            lastKnownLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER);
        }

        if (pendingResult != null) {
            if (lastKnownLocation != null) {
                Map<String, Double> coordinates = new HashMap<>();
                coordinates.put("latitude", lastKnownLocation.getLatitude());
                coordinates.put("longitude", lastKnownLocation.getLongitude());
                pendingResult.success(coordinates);
            } else {
                pendingResult.error("UNAVAILABLE", "Localisation introuvable (Activez le GPS)", null);
            }
            pendingResult = null;
        }
    }

    // 3. Gestion du retour de la demande d'autorisation
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                getLocation(); // On retente la récupération puisque c'est autorisé
            } else if (pendingResult != null) {
                pendingResult.error("PERMISSION_DENIED", "L'utilisateur a refusé l'autorisation", null);
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
