package com.kaique.argila3d;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

public class MainActivity extends Activity {
    private static final int EXPORT_OBJ = 101;
    private final int BG = Color.rgb(14, 19, 27);
    private final int PANEL = Color.rgb(25, 33, 44);
    private final int ACCENT = Color.rgb(72, 224, 183);
    private SculptView editor;
    private LinearLayout brushPanel;
    private TextView status;
    private TextView hint;
    private final Map<SculptView.Mode, TextView> modeButtons = new LinkedHashMap<>();
    private final Map<SculptView.Brush, TextView> brushButtons = new LinkedHashMap<>();

    private int dp(float n) { return (int)(getResources().getDisplayMetrics().density * n + 0.5f); }

    private GradientDrawable box(int color, int radius) {
        GradientDrawable b = new GradientDrawable();
        b.setColor(color);
        b.setCornerRadius(dp(radius));
        return b;
    }

    private TextView label(String text, int size, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(text);
        v.setTextSize(size);
        v.setTextColor(color);
        if (bold) v.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        v.setGravity(Gravity.CENTER_VERTICAL);
        return v;
    }

    private TextView chip(String text, Runnable onClick) {
        TextView v = label(text, 13, Color.WHITE, true);
        v.setGravity(Gravity.CENTER);
        v.setPadding(dp(14), dp(10), dp(14), dp(10));
        v.setBackground(box(PANEL, 12));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 0, dp(7), 0);
        v.setLayoutParams(lp);
        v.setOnClickListener(w -> onClick.run());
        return v;
    }

    private LinearLayout hrow() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setPadding(dp(12), dp(5), dp(5), dp(5));
        return row;
    }

    private HorizontalScrollView scroller(LinearLayout row) {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.addView(row);
        return scroll;
    }

    private void feedback(String s) {
        status.setText(s);
    }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);
        root.setFitsSystemWindows(true);
        setContentView(root);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(16), dp(12), dp(16), dp(5));
        TextView title = label("ARGILA 3D    •    ESTÚDIO", 21, ACCENT, true);
        TextView subtitle = label("Escultura e modelagem por toque  •  v0.1", 12, 0xFFA7B5C4, false);
        header.addView(title);
        header.addView(subtitle);
        root.addView(header);

        hint = label("", 12, 0xFFCFDEE5, false);
        hint.setPadding(dp(16), dp(5), dp(16), dp(6));
        root.addView(hint);

        editor = new SculptView(this);
        root.addView(editor, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        editor.setMesh(ClayMesh.sphere(20, 32));
        editor.setOnChanged(() -> updateStatus());
        String saved = getPreferences(MODE_PRIVATE).getString("mesh", null);
        if (saved != null) {
            try { editor.setMesh(ClayMesh.read(saved)); }
            catch (Exception ignored) { }
        }

        TextView section = label("   FERRAMENTAS", 11, 0xFFA7B5C4, true);
        section.setPadding(0, dp(7), 0, dp(4));
        root.addView(section);

        LinearLayout modes = hrow();
        addMode(modes, "🖐 Esculpir", SculptView.Mode.SCULPT);
        addMode(modes, "• Vértices", SculptView.Mode.VERTEX);
        addMode(modes, "╱ Arestas", SculptView.Mode.EDGE);
        addMode(modes, "▱ Faces", SculptView.Mode.FACE);
        addMode(modes, "⟳ Orbitar", SculptView.Mode.ORBIT);
        root.addView(scroller(modes));

        brushPanel = new LinearLayout(this);
        brushPanel.setOrientation(LinearLayout.VERTICAL);
        LinearLayout brushes = hrow();
        addBrush(brushes, "↑ Puxar", SculptView.Brush.RAISE);
        addBrush(brushes, "↓ Cavar", SculptView.Brush.LOWER);
        addBrush(brushes, "+ Inflar", SculptView.Brush.INFLATE);
        addBrush(brushes, "≈ Suavizar", SculptView.Brush.SMOOTH);
        brushPanel.addView(scroller(brushes));

        LinearLayout sliders = new LinearLayout(this);
        sliders.setOrientation(LinearLayout.HORIZONTAL);
        sliders.setPadding(dp(14), dp(2), dp(10), 0);
        sliders.addView(makeSlider("RAIO", 50, p ->
            editor.setRadiusDp(18 + p * 1.7f)), new LinearLayout.LayoutParams(0, dp(53), 1));
        sliders.addView(makeSlider("FORÇA", 35, p ->
            editor.setStrength(0.008f + p * 0.0015f)), new LinearLayout.LayoutParams(0, dp(53), 1));
        brushPanel.addView(sliders);
        root.addView(brushPanel);

        TextView section2 = label("   PROJETO", 11, 0xFFA7B5C4, true);
        root.addView(section2);
        LinearLayout actions = hrow();
        actions.addView(chip("◯ Esfera", () -> newMesh(ClayMesh.sphere(20, 32))));
        actions.addView(chip("▣ Cubo", () -> newMesh(ClayMesh.cube())));
        actions.addView(chip("↶ Desfazer", () -> {
            if (editor.undo()) feedback("Última alteração desfeita");
            else feedback("Nada para desfazer");
        }));
        actions.addView(chip("▣ Salvar", () -> save()));
        actions.addView(chip("▤ Abrir", () -> load()));
        actions.addView(chip("⇧ Exportar OBJ", () -> exportObj()));
        root.addView(scroller(actions));

        status = label("", 11, 0xFFA7B5C4, false);
        status.setPadding(dp(16), dp(6), dp(16), dp(9));
        root.addView(status);
        editor.setMode(SculptView.Mode.SCULPT);
        editor.setBrush(SculptView.Brush.RAISE);
        refreshActive();
        updateStatus();
    }

    private interface SeekAction { void apply(int value); }
    private LinearLayout makeSlider(String name, int initial, SeekAction action) {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        TextView t = label(name, 10, 0xFFBBD0D9, true);
        column.addView(t);
        SeekBar seek = new SeekBar(this);
        seek.setMax(100);
        seek.setProgress(initial);
        seek.setProgressTintList(android.content.res.ColorStateList.valueOf(ACCENT));
        seek.setThumbTintList(android.content.res.ColorStateList.valueOf(ACCENT));
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar s, int p, boolean fromUser) { action.apply(p); }
            public void onStartTrackingTouch(SeekBar s) { }
            public void onStopTrackingTouch(SeekBar s) { }
        });
        action.apply(initial);
        column.addView(seek, new LinearLayout.LayoutParams(-1, dp(34)));
        return column;
    }

    private void addMode(LinearLayout row, String name, SculptView.Mode mode) {
        TextView v = chip(name, () -> {
            editor.setMode(mode);
            refreshActive();
            updateStatus();
        });
        modeButtons.put(mode, v);
        row.addView(v);
    }

    private void addBrush(LinearLayout row, String name, SculptView.Brush brush) {
        TextView v = chip(name, () -> {
            editor.setBrush(brush);
            refreshActive();
        });
        brushButtons.put(brush, v);
        row.addView(v);
    }

    private void refreshActive() {
        for (Map.Entry<SculptView.Mode, TextView> item : modeButtons.entrySet())
            item.getValue().setBackground(box(editor.mode == item.getKey() ? 0xFF1D715F : PANEL, 12));
        for (Map.Entry<SculptView.Brush, TextView> item : brushButtons.entrySet())
            item.getValue().setBackground(box(editor.brush == item.getKey() ? 0xFF1D715F : PANEL, 12));
        brushPanel.setVisibility(editor.mode == SculptView.Mode.SCULPT ? View.VISIBLE : View.GONE);
        if (editor.mode == SculptView.Mode.SCULPT)
            hint.setText("Arraste na argila para esculpir. Dois dedos giram e dão zoom.");
        else if (editor.mode == SculptView.Mode.ORBIT)
            hint.setText("Arraste para girar. Faça pinça para aproximar ou afastar.");
        else
            hint.setText("Toque para selecionar; arraste para mover. Dois dedos giram e dão zoom.");
    }

    private void updateStatus() {
        if (status != null && editor != null && editor.mesh != null)
            status.setText(editor.mesh.vertices.size() + " vértices  •  " +
                editor.mesh.edges.size() + " arestas  •  " +
                editor.mesh.faces.size() + " faces");
    }

    private void newMesh(ClayMesh mesh) {
        editor.remember();
        editor.setMesh(mesh);
        editor.resetCamera();
        feedback("Nova malha criada. Salve para manter as alterações.");
    }

    private void save() {
        getPreferences(MODE_PRIVATE).edit().putString("mesh", editor.mesh.write(false)).apply();
        Toast.makeText(this, "Projeto salvo no aparelho", Toast.LENGTH_SHORT).show();
    }

    private void load() {
        String data = getPreferences(MODE_PRIVATE).getString("mesh", null);
        if (data == null) { feedback("Nenhum projeto salvo ainda"); return; }
        try {
            editor.remember();
            editor.setMesh(ClayMesh.read(data));
            feedback("Projeto carregado!");
        } catch (Exception ex) {
            feedback("Não foi possível abrir o projeto");
        }
    }

    private void exportObj() {
        Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_TITLE, "argila3d.obj");
        startActivityForResult(i, EXPORT_OBJ);
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != EXPORT_OBJ || result != RESULT_OK || data == null) return;
        Uri uri = data.getData();
        if (uri == null) return;
        try (OutputStream out = getContentResolver().openOutputStream(uri)) {
            if (out == null) throw new IllegalStateException("Arquivo não disponível");
            out.write(editor.mesh.write(true).getBytes(StandardCharsets.UTF_8));
            feedback("Malha OBJ exportada com sucesso!");
            Toast.makeText(this, "Arquivo OBJ salvo", Toast.LENGTH_SHORT).show();
        } catch (Exception ex) {
            feedback("Falha ao exportar OBJ: " + ex.getMessage());
        }
    }
}
