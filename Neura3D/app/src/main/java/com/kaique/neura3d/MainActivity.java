package com.kaique.neura3d;

import android.app.*;
import android.os.*;
import android.content.*;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.opengl.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;

public class MainActivity extends Activity {
    private ModelView modelView;
    private TextView status;
    private LinearLayout toolsRow;
    private final int EXPORT_OBJ = 401;
    private String pendingExport = "";
    private final int bg = Color.rgb(14, 16, 21);
    private final int panel = Color.rgb(23, 26, 33);
    private final int button = Color.rgb(34, 38, 48);
    private final int accent = Color.rgb(74, 158, 255);
    private final int text = Color.rgb(238, 242, 248);

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(bg);
        getWindow().setNavigationBarColor(bg);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(bg);

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(dp(10), dp(6), dp(8), dp(6));
        top.setBackgroundColor(panel);

        TextView brand = new TextView(this);
        brand.setText("Neura3D");
        brand.setTextColor(text);
        brand.setTextSize(18);
        brand.setTypeface(null, 1);
        LinearLayout.LayoutParams brandP = new LinearLayout.LayoutParams(0, dp(40), 1f);
        brand.setGravity(Gravity.CENTER_VERTICAL);
        top.addView(brand, brandP);

        Button add = iconButton("+");
        add.setOnClickListener(v -> showAddMenu(add));
        top.addView(add);

        Button undo = iconButton("↶");
        undo.setOnClickListener(v -> { modelView.undo(); updateStatus(); });
        top.addView(undo);

        Button redo = iconButton("↷");
        redo.setOnClickListener(v -> { modelView.redo(); updateStatus(); });
        top.addView(redo);

        Button menu = iconButton("⋮");
        menu.setOnClickListener(v -> showProjectMenu(menu));
        top.addView(menu);

        root.addView(top, new LinearLayout.LayoutParams(-1, dp(52)));

        modelView = new ModelView(this);
        modelView.setStatusCallback(() -> runOnUiThread(this::updateStatus));
        root.addView(modelView, new LinearLayout.LayoutParams(-1, 0, 1f));

        status = new TextView(this);
        status.setTextColor(Color.rgb(177, 186, 199));
        status.setTextSize(11);
        status.setSingleLine(true);
        status.setGravity(Gravity.CENTER_VERTICAL);
        status.setPadding(dp(12), 0, dp(12), 0);
        status.setBackgroundColor(Color.rgb(18, 20, 26));
        root.addView(status, new LinearLayout.LayoutParams(-1, dp(30)));

        HorizontalScrollView toolScroll = new HorizontalScrollView(this);
        toolScroll.setHorizontalScrollBarEnabled(false);
        toolScroll.setFillViewport(true);
        toolScroll.setBackgroundColor(panel);
        toolsRow = new LinearLayout(this);
        toolsRow.setGravity(Gravity.CENTER_VERTICAL);
        toolsRow.setPadding(dp(7), dp(6), dp(7), dp(6));
        toolScroll.addView(toolsRow, new HorizontalScrollView.LayoutParams(-2, dp(54)));
        root.addView(toolScroll, new LinearLayout.LayoutParams(-1, dp(54)));

        setContentView(root);
        rebuildTools();
        updateStatus();
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private GradientDrawable rounded(int fill, int stroke) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(dp(11));
        g.setStroke(dp(1), stroke);
        return g;
    }

    private Button iconButton(String label) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(text);
        b.setTextSize(19);
        b.setAllCaps(false);
        b.setGravity(Gravity.CENTER);
        b.setPadding(0, 0, 0, 0);
        b.setMinWidth(0);
        b.setMinimumWidth(0);
        b.setMinHeight(0);
        b.setMinimumHeight(0);
        b.setBackground(rounded(button, Color.rgb(48, 53, 65)));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(dp(40), dp(40));
        p.setMargins(dp(3), 0, dp(3), 0);
        b.setLayoutParams(p);
        return b;
    }

    private Button toolButton(String label, boolean active, Runnable action) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(active ? Color.WHITE : Color.rgb(211, 217, 227));
        b.setTextSize(12);
        b.setAllCaps(false);
        b.setSingleLine(true);
        b.setPadding(dp(13), 0, dp(13), 0);
        b.setMinWidth(0);
        b.setMinimumWidth(0);
        b.setBackground(rounded(active ? accent : button, active ? accent : Color.rgb(49, 55, 68)));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-2, dp(40));
        p.setMargins(dp(3), 0, dp(3), 0);
        b.setLayoutParams(p);
        b.setOnClickListener(v -> action.run());
        return b;
    }

    private void showAddMenu(View anchor) {
        PopupMenu p = new PopupMenu(this, anchor);
        p.getMenu().add("Cubo");
        p.getMenu().add("Esfera");
        p.getMenu().add("Cilindro");
        p.setOnMenuItemClickListener(item -> {
            String s = item.getTitle().toString();
            if (s.equals("Cubo")) modelView.addObject("cube");
            else if (s.equals("Esfera")) modelView.addObject("sphere");
            else modelView.addObject("cylinder");
            modelView.setEditMode(false);
            rebuildTools();
            updateStatus();
            return true;
        });
        p.show();
    }

    private void showProjectMenu(View anchor) {
        PopupMenu p = new PopupMenu(this, anchor);
        p.getMenu().add("Salvar projeto");
        p.getMenu().add("Abrir projeto");
        p.getMenu().add("Exportar OBJ");
        p.getMenu().add("Focar seleção");
        p.getMenu().add("Resetar câmera");
        p.setOnMenuItemClickListener(item -> {
            String s = item.getTitle().toString();
            if (s.startsWith("Salvar")) saveInternal();
            else if (s.startsWith("Abrir")) loadInternal();
            else if (s.startsWith("Exportar")) exportObj();
            else if (s.startsWith("Focar")) modelView.focusSelected();
            else modelView.resetCamera();
            updateStatus();
            return true;
        });
        p.show();
    }

    private void rebuildTools() {
        if (toolsRow == null || modelView == null) return;
        toolsRow.removeAllViews();

        toolsRow.addView(toolButton(modelView.isEditMode() ? "EDIT" : "OBJ", true, () -> {
            modelView.setEditMode(!modelView.isEditMode());
            rebuildTools();
            updateStatus();
        }));

        if (!modelView.isEditMode()) {
            toolsRow.addView(toolButton("Câmera", modelView.getObjectMode()==ModelView.MODE_CAMERA, () -> setObjMode(ModelView.MODE_CAMERA)));
            toolsRow.addView(toolButton("Mover", modelView.getObjectMode()==ModelView.MODE_MOVE, () -> setObjMode(ModelView.MODE_MOVE)));
            toolsRow.addView(toolButton("Girar", modelView.getObjectMode()==ModelView.MODE_ROTATE, () -> setObjMode(ModelView.MODE_ROTATE)));
            toolsRow.addView(toolButton("Escala", modelView.getObjectMode()==ModelView.MODE_SCALE, () -> setObjMode(ModelView.MODE_SCALE)));
            toolsRow.addView(toolButton("Duplicar", false, () -> { modelView.duplicateSelected(); updateStatus(); }));
            toolsRow.addView(toolButton("Apagar", false, () -> { modelView.deleteSelected(); updateStatus(); }));
        } else {
            toolsRow.addView(toolButton("Câmera", modelView.getEditTool()==ModelView.ETOOL_CAMERA, () -> setEditTool(ModelView.ETOOL_CAMERA)));
            toolsRow.addView(toolButton("Vértice", modelView.getEditTool()==ModelView.ETOOL_VERTEX, () -> setEditTool(ModelView.ETOOL_VERTEX)));
            toolsRow.addView(toolButton("Face", modelView.getEditTool()==ModelView.ETOOL_FACE, () -> setEditTool(ModelView.ETOOL_FACE)));
            toolsRow.addView(toolButton("Puxar", modelView.getEditTool()==ModelView.ETOOL_PULL, () -> setEditTool(ModelView.ETOOL_PULL)));
            toolsRow.addView(toolButton("Faca", modelView.getEditTool()==ModelView.ETOOL_KNIFE, () -> setEditTool(ModelView.ETOOL_KNIFE)));
            toolsRow.addView(toolButton("Extrudar +", false, () -> { modelView.extrudeFace(0.28f); updateStatus(); }));
            toolsRow.addView(toolButton("Extrudar −", false, () -> { modelView.extrudeFace(-0.28f); updateStatus(); }));
        }
    }

    private void setObjMode(int m) {
        modelView.setObjectMode(m);
        rebuildTools();
        updateStatus();
    }

    private void setEditTool(int t) {
        modelView.setEditTool(t);
        rebuildTools();
        updateStatus();
    }

    private void updateStatus() {
        if (status != null && modelView != null) status.setText(modelView.getStatusText());
    }

    private void saveInternal() {
        try (FileOutputStream out = openFileOutput("autosave.n3d", MODE_PRIVATE)) {
            out.write(modelView.sceneToJson().getBytes(StandardCharsets.UTF_8));
            Toast.makeText(this, "Projeto salvo", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Falha ao salvar", Toast.LENGTH_SHORT).show();
        }
    }

    private void loadInternal() {
        try {
            File f = new File(getFilesDir(), "autosave.n3d");
            if (!f.exists()) {
                Toast.makeText(this, "Nenhum projeto salvo", Toast.LENGTH_SHORT).show();
                return;
            }
            byte[] data = new byte[(int)f.length()];
            try (FileInputStream in = new FileInputStream(f)) {
                int n = in.read(data);
                if (n <= 0) throw new IOException();
            }
            modelView.loadSceneJson(new String(data, StandardCharsets.UTF_8), true);
            modelView.setEditMode(false);
            rebuildTools();
            updateStatus();
            Toast.makeText(this, "Projeto aberto", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Falha ao abrir", Toast.LENGTH_SHORT).show();
        }
    }

    private void exportObj() {
        pendingExport = modelView.exportObj();
        Intent i = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_TITLE, "neura3d_model.obj");
        startActivityForResult(i, EXPORT_OBJ);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == EXPORT_OBJ && resultCode == RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri == null) return;
            try (OutputStream out = getContentResolver().openOutputStream(uri)) {
                if (out != null) out.write(pendingExport.getBytes(StandardCharsets.UTF_8));
                Toast.makeText(this, "OBJ exportado", Toast.LENGTH_SHORT).show();
            } catch (Exception e) {
                Toast.makeText(this, "Falha no export", Toast.LENGTH_SHORT).show();
            }
        }
    }

    @Override protected void onPause() { super.onPause(); if (modelView != null) modelView.onPause(); }
    @Override protected void onResume() { super.onResume(); if (modelView != null) modelView.onResume(); }

    public static class ModelView extends GLSurfaceView {
        public static final int MODE_CAMERA=0, MODE_MOVE=1, MODE_ROTATE=2, MODE_SCALE=3;
        public static final int ETOOL_CAMERA=0, ETOOL_VERTEX=1, ETOOL_FACE=2, ETOOL_PULL=3, ETOOL_KNIFE=4;

        private final SceneRenderer renderer;
        private final ScaleGestureDetector scaler;
        private int objectMode = MODE_CAMERA;
        private int editTool = ETOOL_CAMERA;
        private boolean editMode = false;
        private float downX, downY, lastX, lastY;
        private float lastCX, lastCY;
        private boolean dragging = false;
        private boolean twoFinger = false;
        private String gestureUndo = null;
        private Runnable statusCallback = () -> {};

        public ModelView(Context c) {
            super(c);
            setEGLContextClientVersion(2);
            setPreserveEGLContextOnPause(true);
            renderer = new SceneRenderer();
            setRenderer(renderer);
            setRenderMode(RENDERMODE_CONTINUOUSLY);

            scaler = new ScaleGestureDetector(c, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override public boolean onScale(ScaleGestureDetector d) {
                    renderer.zoom(d.getScaleFactor());
                    statusCallback.run();
                    return true;
                }
            });
            renderer.add("cube");
        }

        public void setStatusCallback(Runnable r) { statusCallback = r == null ? () -> {} : r; }
        public boolean isEditMode() { return editMode; }
        public int getObjectMode() { return objectMode; }
        public int getEditTool() { return editTool; }
        public void setObjectMode(int m) { objectMode = m; statusCallback.run(); }
        public void setEditTool(int t) { editTool = t; statusCallback.run(); }
        public void setEditMode(boolean e) {
            editMode = e;
            if (e) {
                objectMode = MODE_CAMERA;
                editTool = ETOOL_CAMERA;
            }
            renderer.clearElementSelection();
            statusCallback.run();
        }

        public String getStatusText() {
            SceneObject o = renderer.selected();
            if (o == null) return "Nenhum objeto selecionado";
            if (!editMode) {
                String m = objectMode==MODE_CAMERA?"Câmera":objectMode==MODE_MOVE?"Mover":objectMode==MODE_ROTATE?"Girar":"Escala";
                return "OBJ • " + m + " • 1 dedo orbita | 2 dedos movem câmera | pinça dá zoom";
            }
            if (editTool == ETOOL_CAMERA) return "EDIT • Câmera • 1 dedo orbita | 2 dedos movem | pinça zoom";
            if (editTool == ETOOL_VERTEX) return "EDIT • Vértice • toque num vértice para selecionar";
            if (editTool == ETOOL_FACE) return "EDIT • Face • toque numa face para selecionar";
            if (editTool == ETOOL_PULL) return "EDIT • Puxar • arraste o vértice ou face selecionada";
            return "EDIT • Faca • toque numa face para criar um novo corte/ponto";
        }

        @Override public boolean onTouchEvent(MotionEvent e) {
            scaler.onTouchEvent(e);

            if (e.getActionMasked() == MotionEvent.ACTION_POINTER_DOWN || e.getPointerCount() >= 2) {
                twoFinger = true;
                float cx = centroidX(e), cy = centroidY(e);
                if (e.getActionMasked() == MotionEvent.ACTION_POINTER_DOWN) {
                    lastCX = cx; lastCY = cy;
                } else if (e.getActionMasked() == MotionEvent.ACTION_MOVE) {
                    float dx = cx-lastCX, dy = cy-lastCY;
                    if (Math.abs(dx)+Math.abs(dy) > 0.4f) renderer.panCamera(dx,dy,getWidth(),getHeight());
                    lastCX = cx; lastCY = cy;
                    statusCallback.run();
                }
                return true;
            }

            if (e.getActionMasked() == MotionEvent.ACTION_POINTER_UP) {
                twoFinger = true;
                return true;
            }

            float x=e.getX(), y=e.getY();
            switch(e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    twoFinger=false;
                    downX=lastX=x; downY=lastY=y; dragging=false;
                    gestureUndo = renderer.sceneToJson();
                    return true;

                case MotionEvent.ACTION_MOVE:
                    if (twoFinger) return true;
                    float dx=x-lastX, dy=y-lastY;
                    if (Math.abs(x-downX)+Math.abs(y-downY) > 10) dragging=true;

                    if (!editMode) {
                        if (objectMode==MODE_CAMERA) renderer.orbit(dx,dy);
                        else if (objectMode==MODE_MOVE) renderer.moveObject(dx,dy,getWidth(),getHeight());
                        else if (objectMode==MODE_ROTATE) renderer.rotateObject(dx,dy);
                        else renderer.scaleObject(dx-dy);
                    } else {
                        if (editTool==ETOOL_CAMERA) renderer.orbit(dx,dy);
                        else if (editTool==ETOOL_PULL) renderer.pullElement(dx,dy,getWidth(),getHeight());
                    }
                    lastX=x; lastY=y;
                    statusCallback.run();
                    return true;

                case MotionEvent.ACTION_UP:
                    if (twoFinger) { twoFinger=false; return true; }
                    if (!dragging) {
                        if (!editMode) {
                            renderer.pickObject(x,y,getWidth(),getHeight());
                        } else if (editTool==ETOOL_VERTEX) {
                            renderer.pickVertex(x,y,getWidth(),getHeight());
                        } else if (editTool==ETOOL_FACE) {
                            renderer.pickFace(x,y,getWidth(),getHeight());
                        } else if (editTool==ETOOL_KNIFE) {
                            renderer.pushUndo();
                            renderer.knifeAt(x,y,getWidth(),getHeight());
                        }
                    } else {
                        if ((!editMode && objectMode!=MODE_CAMERA) || (editMode && editTool==ETOOL_PULL)) {
                            renderer.commitUndo(gestureUndo);
                        }
                    }
                    gestureUndo=null;
                    statusCallback.run();
                    return true;
            }
            return true;
        }

        private float centroidX(MotionEvent e) {
            float s=0; for(int i=0;i<e.getPointerCount();i++) s+=e.getX(i); return s/e.getPointerCount();
        }
        private float centroidY(MotionEvent e) {
            float s=0; for(int i=0;i<e.getPointerCount();i++) s+=e.getY(i); return s/e.getPointerCount();
        }

        public void addObject(String type) { renderer.pushUndo(); renderer.add(type); statusCallback.run(); }
        public void duplicateSelected() { renderer.pushUndo(); renderer.duplicateSelected(); statusCallback.run(); }
        public void deleteSelected() { renderer.pushUndo(); renderer.deleteSelected(); statusCallback.run(); }
        public void undo() { renderer.undo(); statusCallback.run(); }
        public void redo() { renderer.redo(); statusCallback.run(); }
        public void focusSelected() { renderer.focusSelected(); statusCallback.run(); }
        public void resetCamera() { renderer.resetCamera(); statusCallback.run(); }
        public void extrudeFace(float amount) { renderer.pushUndo(); renderer.extrudeSelectedFace(amount); statusCallback.run(); }
        public String sceneToJson() { return renderer.sceneToJson(); }
        public void loadSceneJson(String json, boolean addUndo) { if(addUndo)renderer.pushUndo(); renderer.loadSceneJson(json); }
        public String exportObj() { return renderer.exportObj(); }
    }

    static class SceneObject {
        int id;
        String type;
        float x,y,z, rx,ry,rz, sx=1,sy=1,sz=1;
        float[] vertices;
        short[] indices;
        transient FloatBuffer vb;
        transient ShortBuffer ib;
        transient boolean dirty = true;

        SceneObject(int id,String type,float[] v,short[] i) {
            this.id=id; this.type=type; vertices=v.clone(); indices=i.clone();
        }

        SceneObject copy(int newId) {
            SceneObject o=new SceneObject(newId,type,vertices,indices);
            o.x=x;o.y=y;o.z=z;o.rx=rx;o.ry=ry;o.rz=rz;o.sx=sx;o.sy=sy;o.sz=sz;
            return o;
        }

        void ensureBuffers() {
            if (!dirty && vb!=null && ib!=null) return;
            vb=ByteBuffer.allocateDirect(vertices.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
            vb.put(vertices).position(0);
            ib=ByteBuffer.allocateDirect(indices.length*2).order(ByteOrder.nativeOrder()).asShortBuffer();
            ib.put(indices).position(0);
            dirty=false;
        }
    }

    static class MeshData {
        final float[] vertices;
        final short[] indices;
        MeshData(float[] v, short[] i) { vertices=v; indices=i; }
    }

    static class FaceHit {
        int face=-1;
        float w0,w1,w2;
        float depth=999f;
    }

    static class SceneRenderer implements GLSurfaceView.Renderer {
        private final List<SceneObject> objects = new ArrayList<>();
        private final Map<String,MeshData> baseMeshes = new HashMap<>();
        private final ArrayDeque<String> undo = new ArrayDeque<>(), redo = new ArrayDeque<>();
        private final AtomicInteger ids = new AtomicInteger(1);

        private int selectedId=-1;
        private int selectedVertex=-1;
        private int selectedFace=-1;

        private int program,aPos,uMvp,uColor;
        private float yaw=35,pitch=-25,distance=8,targetX=0,targetY=0,targetZ=0;
        private final float[] proj=new float[16],view=new float[16],vp=new float[16],model=new float[16],mvp=new float[16];
        private int vw=1,vh=1;
        private FloatBuffer grid;
        private int gridCount;

        SceneRenderer() {
            baseMeshes.put("cube",makeCube());
            baseMeshes.put("sphere",makeSphere(18,24));
            baseMeshes.put("cylinder",makeCylinder(28));
            makeGrid();
        }

        @Override public void onSurfaceCreated(javax.microedition.khronos.opengles.GL10 gl, javax.microedition.khronos.egl.EGLConfig cfg) {
            GLES20.glClearColor(0.045f,0.050f,0.063f,1);
            GLES20.glEnable(GLES20.GL_DEPTH_TEST);
            GLES20.glEnable(GLES20.GL_CULL_FACE);
            program=createProgram(
                "attribute vec3 aPos; uniform mat4 uMvp; void main(){ gl_Position=uMvp*vec4(aPos,1.0); gl_PointSize=15.0; }",
                "precision mediump float; uniform vec4 uColor; void main(){ gl_FragColor=uColor; }"
            );
            aPos=GLES20.glGetAttribLocation(program,"aPos");
            uMvp=GLES20.glGetUniformLocation(program,"uMvp");
            uColor=GLES20.glGetUniformLocation(program,"uColor");
        }

        @Override public void onSurfaceChanged(javax.microedition.khronos.opengles.GL10 gl,int w,int h) {
            vw=Math.max(1,w); vh=Math.max(1,h);
            GLES20.glViewport(0,0,vw,vh);
            Matrix.perspectiveM(proj,0,45f,(float)vw/vh,.05f,100f);
        }

        @Override public void onDrawFrame(javax.microedition.khronos.opengles.GL10 gl) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
            updateCamera();
            GLES20.glUseProgram(program);
            drawGrid();
            List<SceneObject> snap;
            synchronized(this){snap=new ArrayList<>(objects);}
            for(SceneObject o:snap) drawObject(o,o.id==selectedId);
            drawElementSelection();
            drawGizmo();
        }

        private void updateCamera() {
            double yr=Math.toRadians(yaw), pr=Math.toRadians(pitch);
            float cx=targetX+(float)(distance*Math.cos(pr)*Math.sin(yr));
            float cy=targetY+(float)(distance*Math.sin(-pr));
            float cz=targetZ+(float)(distance*Math.cos(pr)*Math.cos(yr));
            Matrix.setLookAtM(view,0,cx,cy,cz,targetX,targetY,targetZ,0,1,0);
            Matrix.multiplyMM(vp,0,proj,0,view,0);
        }

        synchronized void add(String type) {
            MeshData m=baseMeshes.get(type); if(m==null)return;
            SceneObject o=new SceneObject(ids.getAndIncrement(),type,m.vertices,m.indices);
            o.x=(objects.size()%4)*.35f;
            objects.add(o); selectedId=o.id; clearElementSelection();
        }

        synchronized SceneObject selected() {
            for(SceneObject o:objects) if(o.id==selectedId)return o;
            return null;
        }

        synchronized void clearElementSelection(){selectedVertex=-1;selectedFace=-1;}

        synchronized void duplicateSelected() {
            SceneObject s=selected();if(s==null)return;
            SceneObject n=s.copy(ids.getAndIncrement());n.x+=.7f;n.z+=.2f;
            objects.add(n);selectedId=n.id;clearElementSelection();
        }

        synchronized void deleteSelected() {
            objects.removeIf(o->o.id==selectedId);
            selectedId=objects.isEmpty()?-1:objects.get(objects.size()-1).id;
            clearElementSelection();
        }

        void orbit(float dx,float dy) {
            yaw-=dx*.33f;
            pitch=Math.max(-85,Math.min(85,pitch-dy*.29f));
        }

        void panCamera(float dx,float dy,int w,int h) {
            float k=distance/Math.max(240f,Math.min(w,h))*.95f;
            double r=Math.toRadians(yaw);
            targetX -= (float)(dx*Math.cos(r)*k);
            targetZ += (float)(dx*Math.sin(r)*k);
            targetY += dy*k;
        }

        void zoom(float f){if(f>0)distance=Math.max(1.15f,Math.min(40f,distance/f));}

        synchronized void moveObject(float dx,float dy,int w,int h) {
            SceneObject o=selected();if(o==null)return;
            float k=distance/Math.max(260f,Math.min(w,h))*1.6f;
            double r=Math.toRadians(yaw);
            o.x+=(float)(dx*Math.cos(r)*k);
            o.z+=(float)(-dx*Math.sin(r)*k);
            o.y+=-dy*k;
        }

        synchronized void rotateObject(float dx,float dy) {
            SceneObject o=selected();if(o==null)return;
            o.ry+=dx*.55f;o.rx+=dy*.55f;
        }

        synchronized void scaleObject(float d) {
            SceneObject o=selected();if(o==null)return;
            float f=(float)Math.exp(d*.0075);
            o.sx=Math.max(.05f,Math.min(20,o.sx*f));
            o.sy=o.sx;o.sz=o.sx;
        }

        synchronized void pullElement(float dx,float dy,int w,int h) {
            SceneObject o=selected();if(o==null)return;
            float k=distance/Math.max(260f,Math.min(w,h))*1.15f/Math.max(.05f,o.sx);
            double r=Math.toRadians(yaw);
            float lx=(float)(dx*Math.cos(r)*k);
            float lz=(float)(-dx*Math.sin(r)*k);
            float ly=-dy*k;

            if(selectedVertex>=0 && selectedVertex*3+2<o.vertices.length) {
                int p=selectedVertex*3;
                o.vertices[p]+=lx;o.vertices[p+1]+=ly;o.vertices[p+2]+=lz;
                o.dirty=true;
            } else if(selectedFace>=0) {
                int base=selectedFace*3;
                if(base+2>=o.indices.length)return;
                HashSet<Integer> seen=new HashSet<>();
                for(int q=0;q<3;q++) seen.add((int)(o.indices[base+q]&0xffff));
                for(int vi:seen) {
                    int p=vi*3;
                    o.vertices[p]+=lx;o.vertices[p+1]+=ly;o.vertices[p+2]+=lz;
                }
                o.dirty=true;
            }
        }

        synchronized void focusSelected() {
            SceneObject o=selected();if(o==null)return;
            targetX=o.x;targetY=o.y;targetZ=o.z;
            distance=Math.max(2.0f,3.2f*o.sx);
        }

        void resetCamera(){yaw=35;pitch=-25;distance=8;targetX=targetY=targetZ=0;}

        synchronized void pickObject(float x,float y,int w,int h) {
            updateCamera();
            float best=100f,bestDepth=999f;int bestId=-1;
            for(SceneObject o:objects){
                float[] s=projectPoint(o,0,0,0,w,h);
                if(s==null)continue;
                float d=(float)Math.hypot(s[0]-x,s[1]-y);
                if(d<best&&s[2]<bestDepth){best=d;bestDepth=s[2];bestId=o.id;}
            }
            if(bestId!=-1){selectedId=bestId;clearElementSelection();}
        }

        synchronized void pickVertex(float x,float y,int w,int h) {
            SceneObject o=selected();if(o==null)return;
            updateCamera();
            float best=42f,bestDepth=999f;int bestIndex=-1;
            for(int i=0;i<o.vertices.length/3;i++){
                int p=i*3;
                float[] s=projectPoint(o,o.vertices[p],o.vertices[p+1],o.vertices[p+2],w,h);
                if(s==null)continue;
                float d=(float)Math.hypot(s[0]-x,s[1]-y);
                if(d<best&&s[2]<bestDepth){best=d;bestDepth=s[2];bestIndex=i;}
            }
            selectedVertex=bestIndex;
            selectedFace=-1;
        }

        synchronized void pickFace(float x,float y,int w,int h) {
            SceneObject o=selected();if(o==null)return;
            updateCamera();
            FaceHit hit=findFaceHit(o,x,y,w,h);
            selectedFace=hit.face;
            selectedVertex=-1;
        }

        synchronized void knifeAt(float x,float y,int w,int h) {
            SceneObject o=selected();if(o==null)return;
            updateCamera();
            FaceHit hit=findFaceHit(o,x,y,w,h);
            if(hit.face<0)return;
            int off=hit.face*3;
            int ia=o.indices[off]&0xffff, ib=o.indices[off+1]&0xffff, ic=o.indices[off+2]&0xffff;
            int pa=ia*3,pb=ib*3,pc=ic*3;
            float nx=o.vertices[pa]*hit.w0+o.vertices[pb]*hit.w1+o.vertices[pc]*hit.w2;
            float ny=o.vertices[pa+1]*hit.w0+o.vertices[pb+1]*hit.w1+o.vertices[pc+1]*hit.w2;
            float nz=o.vertices[pa+2]*hit.w0+o.vertices[pb+2]*hit.w1+o.vertices[pc+2]*hit.w2;

            int newIndex=o.vertices.length/3;
            if(newIndex>65000)return;
            o.vertices=Arrays.copyOf(o.vertices,o.vertices.length+3);
            o.vertices[o.vertices.length-3]=nx;
            o.vertices[o.vertices.length-2]=ny;
            o.vertices[o.vertices.length-1]=nz;

            short[] ni=new short[o.indices.length+6];
            System.arraycopy(o.indices,0,ni,0,off);
            int q=off;
            ni[q++]=(short)ia;ni[q++]=(short)ib;ni[q++]=(short)newIndex;
            ni[q++]=(short)ib;ni[q++]=(short)ic;ni[q++]=(short)newIndex;
            ni[q++]=(short)ic;ni[q++]=(short)ia;ni[q++]=(short)newIndex;
            System.arraycopy(o.indices,off+3,ni,q,o.indices.length-(off+3));
            o.indices=ni;
            o.dirty=true;
            selectedVertex=newIndex;
            selectedFace=-1;
        }

        synchronized void extrudeSelectedFace(float amount) {
            SceneObject o=selected();if(o==null||selectedFace<0)return;
            int off=selectedFace*3;if(off+2>=o.indices.length)return;
            int a=o.indices[off]&0xffff,b=o.indices[off+1]&0xffff,c=o.indices[off+2]&0xffff;
            float[] av=getV(o,a),bv=getV(o,b),cv=getV(o,c);
            float ux=bv[0]-av[0],uy=bv[1]-av[1],uz=bv[2]-av[2];
            float vx=cv[0]-av[0],vy=cv[1]-av[1],vz=cv[2]-av[2];
            float nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;
            float len=(float)Math.sqrt(nx*nx+ny*ny+nz*nz);if(len<1e-5f)return;
            nx=nx/len*amount;ny=ny/len*amount;nz=nz/len*amount;

            int na=o.vertices.length/3,nb=na+1,nc=na+2;
            if(nc>65000)return;
            float[] nv=Arrays.copyOf(o.vertices,o.vertices.length+9);
            putV(nv,na,av[0]+nx,av[1]+ny,av[2]+nz);
            putV(nv,nb,bv[0]+nx,bv[1]+ny,bv[2]+nz);
            putV(nv,nc,cv[0]+nx,cv[1]+ny,cv[2]+nz);
            o.vertices=nv;

            short[] out=new short[o.indices.length-3+21];
            int q=0;
            for(int i=0;i<o.indices.length;i+=3){
                if(i==off)continue;
                out[q++]=o.indices[i];out[q++]=o.indices[i+1];out[q++]=o.indices[i+2];
            }
            int capFace=q/3;
            out[q++]=(short)na;out[q++]=(short)nb;out[q++]=(short)nc;
            out[q++]=(short)a;out[q++]=(short)b;out[q++]=(short)nb;
            out[q++]=(short)a;out[q++]=(short)nb;out[q++]=(short)na;
            out[q++]=(short)b;out[q++]=(short)c;out[q++]=(short)nc;
            out[q++]=(short)b;out[q++]=(short)nc;out[q++]=(short)nb;
            out[q++]=(short)c;out[q++]=(short)a;out[q++]=(short)na;
            out[q++]=(short)c;out[q++]=(short)na;out[q++]=(short)nc;
            o.indices=out;o.dirty=true;
            selectedFace=capFace;selectedVertex=-1;
        }

        private static float[] getV(SceneObject o,int i){int p=i*3;return new float[]{o.vertices[p],o.vertices[p+1],o.vertices[p+2]};}
        private static void putV(float[] v,int i,float x,float y,float z){int p=i*3;v[p]=x;v[p+1]=y;v[p+2]=z;}

        private FaceHit findFaceHit(SceneObject o,float x,float y,int w,int h) {
            FaceHit best=new FaceHit();
            for(int fi=0;fi<o.indices.length/3;fi++){
                int off=fi*3;
                int ia=o.indices[off]&0xffff,ib=o.indices[off+1]&0xffff,ic=o.indices[off+2]&0xffff;
                float[] a=screenVertex(o,ia,w,h),b=screenVertex(o,ib,w,h),c=screenVertex(o,ic,w,h);
                if(a==null||b==null||c==null)continue;
                float[] bary=barycentric(x,y,a[0],a[1],b[0],b[1],c[0],c[1]);
                if(bary==null)continue;
                float depth=a[2]*bary[0]+b[2]*bary[1]+c[2]*bary[2];
                if(depth<best.depth){
                    best.face=fi;best.depth=depth;best.w0=bary[0];best.w1=bary[1];best.w2=bary[2];
                }
            }
            return best;
        }

        private float[] screenVertex(SceneObject o,int vi,int w,int h){
            int p=vi*3;
            if(p+2>=o.vertices.length)return null;
            return projectPoint(o,o.vertices[p],o.vertices[p+1],o.vertices[p+2],w,h);
        }

        private float[] projectPoint(SceneObject o,float x,float y,float z,int w,int h) {
            float[] mm=matrixFor(o), mvpLocal=new float[16],p={x,y,z,1},clip=new float[4];
            Matrix.multiplyMM(mvpLocal,0,vp,0,mm,0);
            Matrix.multiplyMV(clip,0,mvpLocal,0,p,0);
            if(clip[3]<=.01f)return null;
            float nx=clip[0]/clip[3],ny=clip[1]/clip[3],nz=clip[2]/clip[3];
            return new float[]{(nx*.5f+.5f)*w,(.5f-ny*.5f)*h,nz};
        }

        private static float[] barycentric(float px,float py,float ax,float ay,float bx,float by,float cx,float cy) {
            float v0x=bx-ax,v0y=by-ay,v1x=cx-ax,v1y=cy-ay,v2x=px-ax,v2y=py-ay;
            float d00=v0x*v0x+v0y*v0y,d01=v0x*v1x+v0y*v1y,d11=v1x*v1x+v1y*v1y;
            float d20=v2x*v0x+v2y*v0y,d21=v2x*v1x+v2y*v1y;
            float den=d00*d11-d01*d01;if(Math.abs(den)<1e-6f)return null;
            float v=(d11*d20-d01*d21)/den,w=(d00*d21-d01*d20)/den,u=1-v-w;
            if(u>=-.02f&&v>=-.02f&&w>=-.02f)return new float[]{u,v,w};
            return null;
        }

        synchronized void pushUndo(){undo.addLast(sceneToJson());while(undo.size()>40)undo.removeFirst();redo.clear();}
        synchronized void commitUndo(String before){
            if(before!=null&&!before.equals(sceneToJson())){undo.addLast(before);while(undo.size()>40)undo.removeFirst();redo.clear();}
        }
        synchronized void undo(){if(undo.isEmpty())return;redo.addLast(sceneToJson());loadSceneJson(undo.removeLast());}
        synchronized void redo(){if(redo.isEmpty())return;undo.addLast(sceneToJson());loadSceneJson(redo.removeLast());}

        synchronized String sceneToJson() {
            try{
                JSONObject root=new JSONObject();
                root.put("version",2);root.put("selected",selectedId);
                root.put("yaw",yaw);root.put("pitch",pitch);root.put("distance",distance);
                root.put("tx",targetX);root.put("ty",targetY);root.put("tz",targetZ);
                JSONArray arr=new JSONArray();
                for(SceneObject o:objects){
                    JSONObject j=new JSONObject();
                    j.put("id",o.id);j.put("type",o.type);
                    j.put("x",o.x);j.put("y",o.y);j.put("z",o.z);
                    j.put("rx",o.rx);j.put("ry",o.ry);j.put("rz",o.rz);
                    j.put("sx",o.sx);j.put("sy",o.sy);j.put("sz",o.sz);
                    JSONArray vv=new JSONArray();for(float f:o.vertices)vv.put((double)f);j.put("v",vv);
                    JSONArray ii=new JSONArray();for(short s:o.indices)ii.put(s&0xffff);j.put("i",ii);
                    arr.put(j);
                }
                root.put("objects",arr);return root.toString();
            }catch(Exception e){return "{}";}
        }

        synchronized void loadSceneJson(String s) {
            try{
                JSONObject root=new JSONObject(s);objects.clear();int max=0;
                JSONArray arr=root.optJSONArray("objects");
                if(arr!=null)for(int n=0;n<arr.length();n++){
                    JSONObject j=arr.getJSONObject(n);
                    String type=j.optString("type","cube");
                    MeshData base=baseMeshes.get(type);if(base==null)base=baseMeshes.get("cube");
                    float[] verts=base.vertices.clone();short[] inds=base.indices.clone();
                    JSONArray vv=j.optJSONArray("v"),ii=j.optJSONArray("i");
                    if(vv!=null&&vv.length()>=9){verts=new float[vv.length()];for(int k=0;k<verts.length;k++)verts[k]=(float)vv.optDouble(k);}
                    if(ii!=null&&ii.length()>=3){inds=new short[ii.length()];for(int k=0;k<inds.length;k++)inds[k]=(short)ii.optInt(k);}
                    SceneObject o=new SceneObject(j.optInt("id",ids.getAndIncrement()),type,verts,inds);
                    o.x=(float)j.optDouble("x");o.y=(float)j.optDouble("y");o.z=(float)j.optDouble("z");
                    o.rx=(float)j.optDouble("rx");o.ry=(float)j.optDouble("ry");o.rz=(float)j.optDouble("rz");
                    o.sx=(float)j.optDouble("sx",1);o.sy=(float)j.optDouble("sy",1);o.sz=(float)j.optDouble("sz",1);
                    objects.add(o);max=Math.max(max,o.id);
                }
                ids.set(max+1);selectedId=root.optInt("selected",objects.isEmpty()?-1:objects.get(0).id);
                yaw=(float)root.optDouble("yaw",35);pitch=(float)root.optDouble("pitch",-25);distance=(float)root.optDouble("distance",8);
                targetX=(float)root.optDouble("tx",0);targetY=(float)root.optDouble("ty",0);targetZ=(float)root.optDouble("tz",0);
                clearElementSelection();
            }catch(Exception ignored){}
        }

        synchronized String exportObj() {
            StringBuilder b=new StringBuilder("# Neura3D Studio v0.2 OBJ\n");
            int offset=1,index=0;
            for(SceneObject o:objects){
                b.append("o ").append(o.type).append("_").append(index++).append("\n");
                float[] mm=matrixFor(o);
                for(int i=0;i<o.vertices.length;i+=3){
                    float[] v={o.vertices[i],o.vertices[i+1],o.vertices[i+2],1},out=new float[4];
                    Matrix.multiplyMV(out,0,mm,0,v,0);
                    b.append(String.format(Locale.US,"v %.6f %.6f %.6f\n",out[0],out[1],out[2]));
                }
                for(int i=0;i<o.indices.length;i+=3){
                    int a=(o.indices[i]&0xffff)+offset,c=(o.indices[i+1]&0xffff)+offset,d=(o.indices[i+2]&0xffff)+offset;
                    b.append("f ").append(a).append(' ').append(c).append(' ').append(d).append("\n");
                }
                offset+=o.vertices.length/3;
            }
            return b.toString();
        }

        private void drawObject(SceneObject o,boolean selected) {
            o.ensureBuffers();
            float[] mm=matrixFor(o);Matrix.multiplyMM(mvp,0,vp,0,mm,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            if(selected)GLES20.glUniform4f(uColor,.25f,.62f,.98f,1);
            else if("sphere".equals(o.type))GLES20.glUniform4f(uColor,.60f,.43f,.82f,1);
            else if("cylinder".equals(o.type))GLES20.glUniform4f(uColor,.88f,.50f,.24f,1);
            else GLES20.glUniform4f(uColor,.56f,.61f,.70f,1);
            o.vb.position(0);o.ib.position(0);
            GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,o.vb);
            GLES20.glDrawElements(GLES20.GL_TRIANGLES,o.indices.length,GLES20.GL_UNSIGNED_SHORT,o.ib);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private synchronized void drawElementSelection() {
            SceneObject o=selected();if(o==null)return;
            float[] mm=matrixFor(o);Matrix.multiplyMM(mvp,0,vp,0,mm,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            GLES20.glDisable(GLES20.GL_CULL_FACE);

            if(selectedVertex>=0&&selectedVertex*3+2<o.vertices.length){
                int p=selectedVertex*3;
                FloatBuffer fb=makeFloatBuffer(new float[]{o.vertices[p],o.vertices[p+1],o.vertices[p+2]});
                GLES20.glUniform4f(uColor,1f,.72f,.16f,1);
                GLES20.glEnableVertexAttribArray(aPos);
                GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);
                GLES20.glDrawArrays(GLES20.GL_POINTS,0,1);
                GLES20.glDisableVertexAttribArray(aPos);
            }

            if(selectedFace>=0&&selectedFace*3+2<o.indices.length){
                int q=selectedFace*3;
                int a=o.indices[q]&0xffff,b=o.indices[q+1]&0xffff,c=o.indices[q+2]&0xffff;
                float[] av=getV(o,a),bv=getV(o,b),cv=getV(o,c);
                float[] line={
                    av[0],av[1],av[2], bv[0],bv[1],bv[2],
                    bv[0],bv[1],bv[2], cv[0],cv[1],cv[2],
                    cv[0],cv[1],cv[2], av[0],av[1],av[2]
                };
                FloatBuffer fb=makeFloatBuffer(line);
                GLES20.glUniform4f(uColor,1f,.66f,.12f,1);
                GLES20.glLineWidth(5);
                GLES20.glEnableVertexAttribArray(aPos);
                GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);
                GLES20.glDrawArrays(GLES20.GL_LINES,0,6);
                GLES20.glDisableVertexAttribArray(aPos);
            }
            GLES20.glEnable(GLES20.GL_CULL_FACE);
        }

        private void drawGrid() {
            Matrix.setIdentityM(model,0);Matrix.multiplyMM(mvp,0,vp,0,model,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            GLES20.glUniform4f(uColor,.15f,.17f,.22f,1);
            grid.position(0);GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,grid);
            GLES20.glDrawArrays(GLES20.GL_LINES,0,gridCount);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private synchronized void drawGizmo() {
            SceneObject o=selected();if(o==null)return;
            float s=.72f*Math.max(1,o.sx);
            float[] v={o.x,o.y,o.z,o.x+s,o.y,o.z,o.x,o.y,o.z,o.x,o.y+s,o.z,o.x,o.y,o.z,o.x,o.y,o.z+s};
            FloatBuffer fb=makeFloatBuffer(v);
            Matrix.setIdentityM(model,0);Matrix.multiplyMM(mvp,0,vp,0,model,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            GLES20.glLineWidth(4);
            GLES20.glEnableVertexAttribArray(aPos);
            fb.position(0);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);GLES20.glUniform4f(uColor,1,.25f,.25f,1);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            fb.position(6);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);GLES20.glUniform4f(uColor,.25f,1,.36f,1);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            fb.position(12);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);GLES20.glUniform4f(uColor,.25f,.55f,1,1);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private float[] matrixFor(SceneObject o) {
            float[] mm=new float[16];Matrix.setIdentityM(mm,0);
            Matrix.translateM(mm,0,o.x,o.y,o.z);
            Matrix.rotateM(mm,0,o.ry,0,1,0);Matrix.rotateM(mm,0,o.rx,1,0,0);Matrix.rotateM(mm,0,o.rz,0,0,1);
            Matrix.scaleM(mm,0,o.sx,o.sy,o.sz);return mm;
        }

        private void makeGrid() {
            ArrayList<Float> a=new ArrayList<>();int n=14;float size=14;
            for(int i=-n;i<=n;i++){
                float p=i;
                Collections.addAll(a,-size,0f,p,size,0f,p,p,0f,-size,p,0f,size);
            }
            float[] v=new float[a.size()];for(int i=0;i<v.length;i++)v[i]=a.get(i);
            grid=makeFloatBuffer(v);gridCount=v.length/3;
        }

        private static FloatBuffer makeFloatBuffer(float[] v) {
            FloatBuffer b=ByteBuffer.allocateDirect(v.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
            b.put(v).position(0);return b;
        }

        private static MeshData makeCube() {
            float h=.5f;
            float[] v={-h,-h,-h,h,-h,-h,h,h,-h,-h,h,-h,-h,-h,h,h,-h,h,h,h,h,-h,h,h};
            short[] i={0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,1,2,6,1,6,5,0,4,7,0,7,3};
            return new MeshData(v,i);
        }

        private static MeshData makeSphere(int lat,int lon) {
            ArrayList<Float> v=new ArrayList<>();ArrayList<Short> idx=new ArrayList<>();
            for(int y=0;y<=lat;y++){
                double t=Math.PI*y/lat;
                for(int x=0;x<=lon;x++){
                    double p=2*Math.PI*x/lon;
                    v.add((float)(.5*Math.sin(t)*Math.cos(p)));v.add((float)(.5*Math.cos(t)));v.add((float)(.5*Math.sin(t)*Math.sin(p)));
                }
            }
            for(int y=0;y<lat;y++)for(int x=0;x<lon;x++){
                int a=y*(lon+1)+x,b=a+lon+1;
                idx.add((short)a);idx.add((short)b);idx.add((short)(a+1));
                idx.add((short)(a+1));idx.add((short)b);idx.add((short)(b+1));
            }
            float[] va=new float[v.size()];for(int i=0;i<va.length;i++)va[i]=v.get(i);
            short[] ia=new short[idx.size()];for(int i=0;i<ia.length;i++)ia[i]=idx.get(i);
            return new MeshData(va,ia);
        }

        private static MeshData makeCylinder(int seg) {
            ArrayList<Float> v=new ArrayList<>();ArrayList<Short> idx=new ArrayList<>();
            v.add(0f);v.add(.5f);v.add(0f);v.add(0f);v.add(-.5f);v.add(0f);
            for(int i=0;i<seg;i++){
                double a=2*Math.PI*i/seg;float x=(float)(.5*Math.cos(a)),z=(float)(.5*Math.sin(a));
                v.add(x);v.add(.5f);v.add(z);v.add(x);v.add(-.5f);v.add(z);
            }
            for(int i=0;i<seg;i++){
                int ni=(i+1)%seg;short ti=(short)(2+i*2),bi=(short)(ti+1),tn=(short)(2+ni*2),bn=(short)(tn+1);
                idx.add((short)0);idx.add(tn);idx.add(ti);
                idx.add((short)1);idx.add(bi);idx.add(bn);
                idx.add(ti);idx.add(tn);idx.add(bi);
                idx.add(tn);idx.add(bn);idx.add(bi);
            }
            float[] va=new float[v.size()];for(int i=0;i<va.length;i++)va[i]=v.get(i);
            short[] ia=new short[idx.size()];for(int i=0;i<ia.length;i++)ia[i]=idx.get(i);
            return new MeshData(va,ia);
        }

        private static int createProgram(String vs,String fs) {
            int v=shader(GLES20.GL_VERTEX_SHADER,vs),f=shader(GLES20.GL_FRAGMENT_SHADER,fs);
            int p=GLES20.glCreateProgram();GLES20.glAttachShader(p,v);GLES20.glAttachShader(p,f);GLES20.glLinkProgram(p);
            int[] ok=new int[1];GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
            if(ok[0]==0)throw new RuntimeException(GLES20.glGetProgramInfoLog(p));
            GLES20.glDeleteShader(v);GLES20.glDeleteShader(f);return p;
        }

        private static int shader(int type,String src) {
            int s=GLES20.glCreateShader(type);GLES20.glShaderSource(s,src);GLES20.glCompileShader(s);
            int[] ok=new int[1];GLES20.glGetShaderiv(s,GLES20.GL_COMPILE_STATUS,ok,0);
            if(ok[0]==0)throw new RuntimeException(GLES20.glGetShaderInfoLog(s));
            return s;
        }
    }
}
