package com.salama_drc.terminal;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Rect;
import android.util.Log;
import androidx.annotation.OptIn;
import androidx.camera.core.ExperimentalGetImage;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import com.google.android.gms.tasks.Tasks;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.face.Face;
import com.google.mlkit.vision.face.FaceDetection;
import com.google.mlkit.vision.face.FaceDetector;
import com.google.mlkit.vision.face.FaceDetectorOptions;
import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.support.common.ops.NormalizeOp;
import org.tensorflow.lite.support.image.ImageProcessor;
import org.tensorflow.lite.support.image.TensorImage;
import org.tensorflow.lite.support.image.ops.ResizeOp;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class FaceRecognitionProcessor {
    private static final String TAG = "FaceProcessor";
    private final Interpreter interpreter;
    private final FaceDetector detector;
    private final DatabaseHelper dbHelper;
    private final Context context;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    
    private int livenessStep = 0; 
    private int stableFrames = 0;
    private long lastAnalysisTime = 0;

    public interface FaceCallback {
        void onFaceState(String state);
        void onChallengeRequired(String challenge);
        void onResult(String matricule, float distance, String imagePath);
        void onError(String error);
    }

    public FaceRecognitionProcessor(Context context) throws IOException {
        this.context = context;
        this.interpreter = new Interpreter(loadModelFile(context, "facenet.tflite"));
        this.dbHelper = new DatabaseHelper(context);
        
        FaceDetectorOptions options = new FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .build();
        this.detector = FaceDetection.getClient(options);
    }

    private MappedByteBuffer loadModelFile(Context context, String modelPath) throws IOException {
        AssetFileDescriptor fileDescriptor = context.getAssets().openFd(modelPath);
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, fileDescriptor.getStartOffset(), fileDescriptor.getDeclaredLength());
    }

    @OptIn(markerClass = ExperimentalGetImage.class)
    public void analyzeImage(ImageProxy imageProxy, boolean forceCapture, FaceCallback callback) {
        long currentTime = System.currentTimeMillis();
        // Limiter à 5 analyses par seconde pour économiser le CPU du SM-A05
        if (!forceCapture && currentTime - lastAnalysisTime < 200) {
            imageProxy.close();
            return;
        }
        lastAnalysisTime = currentTime;

        if (imageProxy.getImage() == null) { imageProxy.close(); return; }
        InputImage image = InputImage.fromMediaImage(imageProxy.getImage(), imageProxy.getImageInfo().getRotationDegrees());
        
        detector.process(image)
                .addOnSuccessListener(faces -> {
                    if (faces.isEmpty()) {
                        stableFrames = 0;
                        callback.onFaceState("WAIT_FACE");
                        imageProxy.close();
                    } else {
                        if (forceCapture) {
                            runRecognition(imageProxy, faces.get(0), true, callback);
                        } else {
                            processFaces(faces, imageProxy, callback);
                        }
                    }
                })
                .addOnFailureListener(e -> {
                    callback.onError(e.getMessage());
                    imageProxy.close();
                });
    }

    private void processFaces(List<Face> faces, ImageProxy imageProxy, FaceCallback callback) {
        Face face = faces.get(0);
        Rect bounds = face.getBoundingBox();
        if (bounds.width() < 50) { callback.onFaceState("TOO_FAR"); imageProxy.close(); return; }

        if (livenessStep == 0) {
            stableFrames++;
            if (stableFrames >= 3) { // Réduit pour plus de réactivité
                livenessStep = 1;
                callback.onChallengeRequired("BLINK");
            } else { callback.onFaceState("STABILIZING"); }
            imageProxy.close();
            return;
        }

        if (livenessStep == 1) {
            Float left = face.getLeftEyeOpenProbability();
            Float right = face.getRightEyeOpenProbability();
            if (left != null && right != null && (left < 0.4 || right < 0.4)) {
                livenessStep = 2;
                callback.onFaceState("CAPTURING");
                runRecognition(imageProxy, face, false, callback);
            } else { imageProxy.close(); }
            return;
        }
        imageProxy.close();
    }

    private void runRecognition(ImageProxy imageProxy, Face face, boolean isManual, FaceCallback callback) {
        executor.execute(() -> {
            try {
                Bitmap bitmap = ImageUtils.toBitmap(imageProxy);
                if (bitmap == null) return;

                Bitmap faceBitmap = extractFace(bitmap, face.getBoundingBox());
                float[] embedding = getEmbedding(faceBitmap);
                
                String bestMatricule = "Inconnu";
                float minDistance = Float.MAX_VALUE;

                List<DatabaseHelper.FaceTemplate> templates = dbHelper.getAllTemplates();
                Log.d(TAG, "Comparing with " + templates.size() + " templates");

                for (DatabaseHelper.FaceTemplate template : templates) {
                    float dist = euclideanDistance(embedding, template.embedding);
                    if (dist < minDistance) { 
                        minDistance = dist; 
                        bestMatricule = template.matricule; 
                    }
                }

                Log.d(TAG, "Best match: " + bestMatricule + " distance: " + minDistance);

                // Seuil augmenté à 0.85 pour compenser la qualité du SM-A05
                if (minDistance > 0.85f) bestMatricule = "Inconnu";

                String path = saveToCache(faceBitmap);
                callback.onResult(bestMatricule, minDistance, path);
                
                if (!isManual) { livenessStep = 0; stableFrames = 0; }
            } catch (Exception e) { 
                Log.e(TAG, "Recognition error", e);
                callback.onError(e.getMessage()); 
            }
            finally { imageProxy.close(); }
        });
    }

    private Bitmap extractFace(Bitmap full, Rect rect) {
        try {
            int margin = 40;
            int l = Math.max(0, rect.left - margin);
            int t = Math.max(0, rect.top - margin);
            int w = Math.min(rect.width() + (margin * 2), full.getWidth() - l);
            int h = Math.min(rect.height() + (margin * 2), full.getHeight() - t);
            return Bitmap.createBitmap(full, l, t, w, h);
        } catch (Exception e) { return full; }
    }

    public void processEnrollment(String matricule, List<String> paths) {
        executor.execute(() -> {
            for (String path : paths) {
                try {
                    Bitmap bitmap = BitmapFactory.decodeFile(path);
                    if (bitmap == null) continue;
                    InputImage input = InputImage.fromBitmap(bitmap, 0);
                    // Utilisation de Tasks.await pour bloquer proprement sur le thread d'exécution
                    List<Face> faces = Tasks.await(detector.process(input));
                    if (!faces.isEmpty()) {
                        Bitmap faceOnly = extractFace(bitmap, faces.get(0).getBoundingBox());
                        float[] embedding = getEmbedding(faceOnly);
                        dbHelper.insertTemplate(matricule, embedding, 1.0f, 0, 0);
                        Log.d(TAG, "SUCCESS: Enrolled " + matricule);
                    } else {
                        Log.w(TAG, "No face found in enrollment photo: " + path);
                    }
                } catch (Exception e) { Log.e(TAG, "Enrollment failed", e); }
            }
        });
    }

    private String saveToCache(Bitmap bitmap) {
        try {
            File f = File.createTempFile("face_", ".jpg", context.getCacheDir());
            FileOutputStream out = new FileOutputStream(f);
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out);
            out.close();
            return f.getAbsolutePath();
        } catch (IOException e) { return null; }
    }

    private float[] getEmbedding(Bitmap bitmap) {
        ImageProcessor processor = new ImageProcessor.Builder()
                .add(new ResizeOp(112, 112, ResizeOp.ResizeMethod.BILINEAR))
                .add(new NormalizeOp(127.5f, 127.5f)) // Normalisation standard FaceNet
                .build();
        TensorImage tensorImage = new TensorImage(org.tensorflow.lite.DataType.FLOAT32);
        tensorImage.load(bitmap);
        tensorImage = processor.process(tensorImage);
        float[][] output = new float[1][128];
        interpreter.run(tensorImage.getBuffer(), output);
        return normalize(output[0]);
    }

    private float[] normalize(float[] e) {
        float s = 0; for (float v : e) s += v * v;
        float n = (float) Math.sqrt(s);
        for (int i = 0; i < e.length; i++) e[i] /= n;
        return e;
    }

    private float euclideanDistance(float[] e1, float[] e2) {
        float s = 0; for (int i = 0; i < e1.length; i++) {
            float d = e1[i] - e2[i]; s += d * d;
        }
        return (float) Math.sqrt(s);
    }
}
