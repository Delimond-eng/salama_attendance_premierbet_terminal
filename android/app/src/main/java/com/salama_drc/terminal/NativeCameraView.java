package com.salama_drc.terminal;

import android.content.Context;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.view.PreviewView;
import io.flutter.plugin.platform.PlatformView;

public class NativeCameraView implements PlatformView {
    private final PreviewView previewView;

    NativeCameraView(@NonNull Context context, int id, @Nullable Object creationParams) {
        previewView = new PreviewView(context);
        previewView.setImplementationMode(PreviewView.ImplementationMode.COMPATIBLE);
        // We'll bind the camera to this previewView from the MainActivity/Controller
    }

    @Override
    public View getView() {
        return previewView;
    }

    @Override
    public void dispose() {
        // Cleanup handled by CameraManager/MainActivity
    }

    public PreviewView getPreviewView() {
        return previewView;
    }
}
