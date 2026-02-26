package com.salama_drc.terminal;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import java.util.ArrayList;
import java.util.List;

public class DatabaseHelper extends SQLiteOpenHelper {
    private static final String DATABASE_NAME = "terminal_faces.db";
    private static final int DATABASE_VERSION = 1;

    public DatabaseHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE agents (matricule TEXT PRIMARY KEY, name TEXT)");
        db.execSQL("CREATE TABLE face_templates (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "matricule TEXT, " +
                "embedding BLOB, " +
                "quality REAL, " +
                "yaw REAL, " +
                "pitch REAL, " +
                "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)");
        db.execSQL("CREATE INDEX idx_matricule ON face_templates(matricule)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {}

    public void insertTemplate(String matricule, float[] embedding, float quality, float yaw, float pitch) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put("matricule", matricule);
        values.put("embedding", floatArrayToByteArray(embedding));
        values.put("quality", quality);
        values.put("yaw", yaw);
        values.put("pitch", pitch);
        db.insert("face_templates", null, values);
    }

    public List<FaceTemplate> getAllTemplates() {
        List<FaceTemplate> templates = new ArrayList<>();
        SQLiteDatabase db = getReadableDatabase();
        Cursor cursor = db.query("face_templates", null, null, null, null, null, null);
        while (cursor.moveToNext()) {
            String matricule = cursor.getString(cursor.getColumnIndexOrThrow("matricule"));
            byte[] blob = cursor.getBlob(cursor.getColumnIndexOrThrow("embedding"));
            float[] embedding = byteArrayToFloatArray(blob);
            templates.add(new FaceTemplate(matricule, embedding));
        }
        cursor.close();
        return templates;
    }

    private byte[] floatArrayToByteArray(float[] input) {
        java.nio.ByteBuffer buffer = java.nio.ByteBuffer.allocate(input.length * 4);
        for (float f : input) buffer.putFloat(f);
        return buffer.array();
    }

    private float[] byteArrayToFloatArray(byte[] input) {
        java.nio.FloatBuffer buffer = java.nio.ByteBuffer.wrap(input).asFloatBuffer();
        float[] output = new float[buffer.remaining()];
        buffer.get(output);
        return output;
    }

    public static class FaceTemplate {
        public String matricule;
        public float[] embedding;
        public FaceTemplate(String matricule, float[] embedding) {
            this.matricule = matricule;
            this.embedding = embedding;
        }
    }
}
