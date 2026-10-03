package com.kaique.neura3d;

import android.app.*;
import android.os.*;
import android.content.*;
import android.graphics.Color;
import android.net.Uri;
import android.opengl.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import android.graphics.drawable.GradientDrawable;
import org.json.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;

public class MainActivity extends Activity {
    private ModelView modelView;
    private TextView status;
    private final int EXPORT_OBJ = 401;
    private String pendingExport = "";
    private final int bg = Color.rgb(17, 19, 24);
    private final int panel = Color.rgb(28, 31, 39);
    private final int accent = Color.rgb(78, 161, 255);
    private final int text = Color.rgb(238, 242, 248);

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(bg);
        getWindow().setNavigationBarColor(bg);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(bg);

        HorizontalScrollView topScroll = new HorizontalScrollView(this);
        topScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(dp(8), dp(6), dp(8), dp(6));
        top.setBackgroundColor(panel);

        TextView brand = new TextView(this);
        brand.setText("NEURA3D");
        brand.setTextColor(text);
        brand.setTextSize(17);
        brand.setTypeface(null, 1);
        brand.setPadding(dp(8), 0, dp(14), 0);
        top.addView(brand);

        modelView = new ModelView(this);
        addButton(top, "+ Cubo", () -> { modelView.addObject("cube"); updateStatus(); });
        addButton(top, "+ Esfera", () -> { modelView.addObject("sphere"); updateStatus(); });
        addButton(top, "+ Cilindro", () -> { modelView.addObject("cylinder"); updateStatus(); });
        addButton(top, "Duplicar", () -> { modelView.duplicateSelected(); updateStatus(); });
        addButton(top, "Apagar", () -> { modelView.deleteSelected(); updateStatus(); });
        addButton(top, "Desfazer", () -> { modelView.undo(); updateStatus(); });
        addButton(top, "Refazer", () -> { modelView.redo(); updateStatus(); });
        addButton(top, "Salvar", () -> { saveInternal(); });
        addButton(top, "Abrir", () -> { loadInternal(); });
        addButton(top, "Exportar OBJ", this::exportObj);

        topScroll.addView(top);
        root.addView(topScroll, new LinearLayout.LayoutParams(-1, dp(52)));

        root.addView(modelView, new LinearLayout.LayoutParams(-1, 0, 1f));

        LinearLayout tools = new LinearLayout(this);
        tools.setGravity(Gravity.CENTER);
        tools.setPadding(dp(6), dp(6), dp(6), dp(6));
        tools.setBackgroundColor(panel);
        addModeButton(tools, "Câmera", ModelView.MODE_CAMERA);
        addModeButton(tools, "Mover", ModelView.MODE_MOVE);
        addModeButton(tools, "Rotacionar", ModelView.MODE_ROTATE);
        addModeButton(tools, "Escalar", ModelView.MODE_SCALE);
        addButton(tools, "Foco", () -> modelView.focusSelected());
        root.addView(tools, new LinearLayout.LayoutParams(-1, dp(54)));

        status = new TextView(this);
        status.setTextColor(Color.rgb(190, 198, 210));
        status.setTextSize(12);
        status.setGravity(Gravity.CENTER_VERTICAL);
        status.setPadding(dp(12), 0, dp(12), 0);
        status.setBackgroundColor(Color.rgb(20, 22, 28));
        root.addView(status, new LinearLayout.LayoutParams(-1, dp(34)));

        setContentView(root);
        modelView.setStatusCallback(this::updateStatus);
        updateStatus();
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private Button styledButton(String label) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(text);
        b.setTextSize(12);
        b.setAllCaps(false);
        b.setPadding(dp(11), 0, dp(11), 0);
        b.setMinHeight(dp(38));
        b.setMinWidth(0);
        GradientDrawable g = new GradientDrawable();
        g.setColor(Color.rgb(39, 43, 53));
        g.setCornerRadius(dp(9));
        g.setStroke(dp(1), Color.rgb(58, 63, 76));
        b.setBackground(g);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-2, dp(38));
        p.setMargins(dp(3), 0, dp(3), 0);
        b.setLayoutParams(p);
        return b;
    }

    private void addButton(LinearLayout parent, String label, Runnable r) {
        Button b = styledButton(label);
        b.setOnClickListener(v -> r.run());
        parent.addView(b);
    }

    private void addModeButton(LinearLayout parent, String label, int mode) {
        Button b = styledButton(label);
        b.setOnClickListener(v -> {
            modelView.setMode(mode);
            updateStatus();
        });
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(40), 1f);
        p.setMargins(dp(3), 0, dp(3), 0);
        b.setLayoutParams(p);
        parent.addView(b);
    }

    private void updateStatus() {
        if (status == null || modelView == null) return;
        status.setText(modelView.getStatusText());
    }

    private void saveInternal() {
        try {
            try (FileOutputStream out = openFileOutput("autosave.n3d", MODE_PRIVATE)) {
                out.write(modelView.sceneToJson().getBytes(StandardCharsets.UTF_8));
            }
            toast("Projeto salvo");
        } catch (Exception e) { toast("Falha ao salvar: " + e.getMessage()); }
    }

    private void loadInternal() {
        try {
            File f = new File(getFilesDir(), "autosave.n3d");
            if (!f.exists()) { toast("Ainda não existe projeto salvo"); return; }
            byte[] data = new byte[(int) f.length()];
            try (FileInputStream in = new FileInputStream(f)) {
                int n = in.read(data);
                if (n <= 0) throw new IOException("arquivo vazio");
            }
            modelView.loadSceneJson(new String(data, StandardCharsets.UTF_8), true);
            updateStatus();
            toast("Projeto aberto");
        } catch (Exception e) { toast("Falha ao abrir: " + e.getMessage()); }
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
                toast("OBJ exportado");
            } catch (Exception e) { toast("Falha no export: " + e.getMessage()); }
        }
    }

    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_SHORT).show(); }

    @Override protected void onPause() { super.onPause(); modelView.onPause(); }
    @Override protected void onResume() { super.onResume(); modelView.onResume(); }

    public static class ModelView extends GLSurfaceView {
        public static final int MODE_CAMERA=0, MODE_MOVE=1, MODE_ROTATE=2, MODE_SCALE=3;
        private final SceneRenderer renderer;
        private final ScaleGestureDetector scaler;
        private float downX, downY, lastX, lastY;
        private boolean dragging;
        private int mode = MODE_CAMERA;
        private Runnable statusCallback = () -> {};
        private String gestureUndo = null;

        public ModelView(Context c) {
            super(c);
            setEGLContextClientVersion(2);
            renderer = new SceneRenderer();
            setRenderer(renderer);
            setRenderMode(RENDERMODE_CONTINUOUSLY);
            scaler = new ScaleGestureDetector(c, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override public boolean onScale(ScaleGestureDetector detector) {
                    renderer.zoom(detector.getScaleFactor());
                    statusCallback.run();
                    return true;
                }
            });
            addObject("cube");
        }

        public void setStatusCallback(Runnable r) { statusCallback = r == null ? () -> {} : r; }
        public void setMode(int m) { mode = m; statusCallback.run(); }
        public String getStatusText() {
            String m = mode==MODE_CAMERA?"Câmera":mode==MODE_MOVE?"Mover":mode==MODE_ROTATE?"Rotacionar":"Escalar";
            SceneObject o = renderer.selected();
            if (o == null) return m + "  •  Nenhum objeto  •  Arraste para navegar";
            return m + "  •  " + o.type.toUpperCase(Locale.ROOT) + "  •  P(" + fmt(o.x)+", "+fmt(o.y)+", "+fmt(o.z)+")  R(" + fmt(o.rx)+", "+fmt(o.ry)+", "+fmt(o.rz)+")  S(" + fmt(o.sx)+")";
        }
        private String fmt(float v) { return String.format(Locale.US, "%.2f", v); }

        @Override public boolean onTouchEvent(android.view.MotionEvent e) {
            scaler.onTouchEvent(e);
            if (e.getPointerCount() > 1) return true;
            float x=e.getX(), y=e.getY();
            switch(e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX=lastX=x; downY=lastY=y; dragging=false;
                    gestureUndo = renderer.sceneToJson();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    float dx=x-lastX, dy=y-lastY;
                    if (Math.abs(x-downX)+Math.abs(y-downY) > 10) dragging=true;
                    if (!scaler.isInProgress()) {
                        if (mode==MODE_CAMERA) renderer.orbit(dx,dy);
                        else if (mode==MODE_MOVE) renderer.moveSelected(dx,dy,getWidth(),getHeight());
                        else if (mode==MODE_ROTATE) renderer.rotateSelected(dx,dy);
                        else if (mode==MODE_SCALE) renderer.scaleSelected(dx-dy);
                        statusCallback.run();
                    }
                    lastX=x; lastY=y;
                    return true;
                case MotionEvent.ACTION_UP:
                    if (!dragging) {
                        renderer.pick(x,y,getWidth(),getHeight());
                    } else if (mode != MODE_CAMERA && gestureUndo != null) {
                        renderer.commitUndo(gestureUndo);
                    }
                    gestureUndo = null;
                    statusCallback.run();
                    return true;
            }
            return true;
        }

        public void addObject(String type) { renderer.pushUndo(); renderer.add(type); statusCallback.run(); }
        public void duplicateSelected() { renderer.pushUndo(); renderer.duplicateSelected(); statusCallback.run(); }
        public void deleteSelected() { renderer.pushUndo(); renderer.deleteSelected(); statusCallback.run(); }
        public void undo() { renderer.undo(); statusCallback.run(); }
        public void redo() { renderer.redo(); statusCallback.run(); }
        public void focusSelected() { renderer.focusSelected(); statusCallback.run(); }
        public String sceneToJson() { return renderer.sceneToJson(); }
        public void loadSceneJson(String json, boolean addUndo) { if(addUndo)renderer.pushUndo(); renderer.loadSceneJson(json); }
        public String exportObj() { return renderer.exportObj(); }
    }

    static class SceneObject {
        int id;
        String type;
        float x,y,z, rx,ry,rz, sx=1,sy=1,sz=1;
        SceneObject(int id,String type){this.id=id;this.type=type;}
        SceneObject copy(int newId) {
            SceneObject o=new SceneObject(newId,type);
            o.x=x;o.y=y;o.z=z;o.rx=rx;o.ry=ry;o.rz=rz;o.sx=sx;o.sy=sy;o.sz=sz;
            return o;
        }
    }

    static class MeshData {
        final float[] vertices;
        final short[] indices;
        FloatBuffer vb; ShortBuffer ib;
        MeshData(float[] v, short[] i) {
            vertices=v; indices=i;
            vb=ByteBuffer.allocateDirect(v.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
            vb.put(v).position(0);
            ib=ByteBuffer.allocateDirect(i.length*2).order(ByteOrder.nativeOrder()).asShortBuffer();
            ib.put(i).position(0);
        }
    }

    static class SceneRenderer implements GLSurfaceView.Renderer {
        private final List<SceneObject> objects = new ArrayList<>();
        private final Map<String,MeshData> meshes = new HashMap<>();
        private final ArrayDeque<String> undo = new ArrayDeque<>(), redo = new ArrayDeque<>();
        private final AtomicInteger ids = new AtomicInteger(1);
        private int selectedId=-1, program, aPos, uMvp, uColor;
        private float yaw=35, pitch=-25, distance=8f, targetX=0,targetY=0,targetZ=0;
        private final float[] proj=new float[16], view=new float[16], vp=new float[16], model=new float[16], mvp=new float[16];
        private int vw=1,vh=1;
        private FloatBuffer grid;
        private int gridCount;

        SceneRenderer() {
            meshes.put("cube", makeCube());
            meshes.put("sphere", makeSphere(18,24));
            meshes.put("cylinder", makeCylinder(28));
            makeGrid();
        }

        @Override public void onSurfaceCreated(javax.microedition.khronos.opengles.GL10 gl, javax.microedition.khronos.egl.EGLConfig cfg) {
            GLES20.glClearColor(0.055f,0.062f,0.078f,1f);
            GLES20.glEnable(GLES20.GL_DEPTH_TEST);
            GLES20.glEnable(GLES20.GL_CULL_FACE);
            program = createProgram(
                "attribute vec3 aPos; uniform mat4 uMvp; void main(){ gl_Position=uMvp*vec4(aPos,1.0); }",
                "precision mediump float; uniform vec4 uColor; void main(){ gl_FragColor=uColor; }"
            );
            aPos=GLES20.glGetAttribLocation(program,"aPos");
            uMvp=GLES20.glGetUniformLocation(program,"uMvp");
            uColor=GLES20.glGetUniformLocation(program,"uColor");
        }

        @Override public void onSurfaceChanged(javax.microedition.khronos.opengles.GL10 gl,int w,int h) {
            vw=Math.max(1,w); vh=Math.max(1,h);
            GLES20.glViewport(0,0,vw,vh);
            Matrix.perspectiveM(proj,0,45f,(float)vw/vh,0.05f,100f);
        }

        @Override public void onDrawFrame(javax.microedition.khronos.opengles.GL10 gl) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
            updateCamera();
            GLES20.glUseProgram(program);
            drawGrid();
            for(SceneObject o: new ArrayList<>(objects)) drawObject(o, o.id==selectedId);
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
            SceneObject o=new SceneObject(ids.getAndIncrement(),type);
            o.x=(objects.size()%4)*0.35f;
            selectedId=o.id; objects.add(o);
        }

        synchronized SceneObject selected() {
            for(SceneObject o:objects) if(o.id==selectedId) return o;
            return null;
        }

        synchronized void duplicateSelected() {
            SceneObject s=selected(); if(s==null)return;
            SceneObject n=s.copy(ids.getAndIncrement()); n.x+=0.65f; n.z+=0.25f;
            objects.add(n); selectedId=n.id;
        }

        synchronized void deleteSelected() {
            objects.removeIf(o->o.id==selectedId);
            selectedId=objects.isEmpty()?-1:objects.get(objects.size()-1).id;
        }

        void orbit(float dx,float dy){ yaw-=dx*0.35f; pitch=Math.max(-85,Math.min(85,pitch-dy*0.30f)); }
        void zoom(float f){ if(f>0)distance=Math.max(1.3f,Math.min(35f,distance/f)); }

        synchronized void moveSelected(float dx,float dy,int w,int h){
            SceneObject o=selected(); if(o==null)return;
            float k=distance/Math.max(260f,Math.min(w,h))*1.65f;
            double r=Math.toRadians(yaw);
            o.x += (float)(dx*Math.cos(r)*k);
            o.z += (float)(-dx*Math.sin(r)*k);
            o.y += -dy*k;
        }
        synchronized void rotateSelected(float dx,float dy){
            SceneObject o=selected(); if(o==null)return;
            o.ry += dx*0.6f; o.rx += dy*0.6f;
        }
        synchronized void scaleSelected(float d){
            SceneObject o=selected(); if(o==null)return;
            float f=(float)Math.exp(d*0.008);
            o.sx=Math.max(.05f,Math.min(20,o.sx*f));
            o.sy=o.sx; o.sz=o.sx;
        }
        synchronized void focusSelected(){
            SceneObject o=selected(); if(o==null)return;
            targetX=o.x;targetY=o.y;targetZ=o.z;
            distance=Math.max(2.2f,3.3f*o.sx);
        }

        synchronized void pick(float x,float y,int w,int h) {
            updateCamera();
            float best=92f, bestDepth=999f; int bestId=-1;
            for(SceneObject o:objects) {
                float[] p={o.x,o.y,o.z,1}, clip=new float[4];
                Matrix.multiplyMV(clip,0,vp,0,p,0);
                if(clip[3]<=0.01f)continue;
                float nx=clip[0]/clip[3], ny=clip[1]/clip[3], nz=clip[2]/clip[3];
                float sx=(nx*.5f+.5f)*w, sy=(.5f-ny*.5f)*h;
                float d=(float)Math.hypot(sx-x,sy-y);
                if(d<best && nz<bestDepth){best=d;bestDepth=nz;bestId=o.id;}
            }
            if(bestId!=-1)selectedId=bestId;
        }

        synchronized void pushUndo(){ undo.addLast(sceneToJson()); trimHistory(); redo.clear(); }
        synchronized void commitUndo(String before){ if(before!=null && !before.equals(sceneToJson())){undo.addLast(before);trimHistory();redo.clear();} }
        private void trimHistory(){while(undo.size()>40)undo.removeFirst();}
        synchronized void undo(){ if(undo.isEmpty())return; redo.addLast(sceneToJson()); loadSceneJson(undo.removeLast()); }
        synchronized void redo(){ if(redo.isEmpty())return; undo.addLast(sceneToJson()); loadSceneJson(redo.removeLast()); }

        synchronized String sceneToJson() {
            try {
                JSONObject root=new JSONObject();
                root.put("version",1); root.put("selected",selectedId);
                root.put("cameraYaw",yaw);root.put("cameraPitch",pitch);root.put("cameraDistance",distance);
                root.put("targetX",targetX);root.put("targetY",targetY);root.put("targetZ",targetZ);
                JSONArray arr=new JSONArray();
                for(SceneObject o:objects){
                    JSONObject j=new JSONObject();
                    j.put("id",o.id);j.put("type",o.type);
                    j.put("x",o.x);j.put("y",o.y);j.put("z",o.z);
                    j.put("rx",o.rx);j.put("ry",o.ry);j.put("rz",o.rz);
                    j.put("sx",o.sx);j.put("sy",o.sy);j.put("sz",o.sz);
                    arr.put(j);
                }
                root.put("objects",arr);
                return root.toString();
            }catch(Exception e){return "{}";}
        }

        synchronized void loadSceneJson(String s) {
            try {
                JSONObject root=new JSONObject(s);
                objects.clear();
                JSONArray arr=root.optJSONArray("objects");
                int max=0;
                if(arr!=null)for(int i=0;i<arr.length();i++){
                    JSONObject j=arr.getJSONObject(i);
                    SceneObject o=new SceneObject(j.optInt("id",ids.getAndIncrement()),j.optString("type","cube"));
                    o.x=(float)j.optDouble("x");o.y=(float)j.optDouble("y");o.z=(float)j.optDouble("z");
                    o.rx=(float)j.optDouble("rx");o.ry=(float)j.optDouble("ry");o.rz=(float)j.optDouble("rz");
                    o.sx=(float)j.optDouble("sx",1);o.sy=(float)j.optDouble("sy",1);o.sz=(float)j.optDouble("sz",1);
                    objects.add(o);max=Math.max(max,o.id);
                }
                ids.set(max+1);
                selectedId=root.optInt("selected",objects.isEmpty()?-1:objects.get(0).id);
                yaw=(float)root.optDouble("cameraYaw",35);pitch=(float)root.optDouble("cameraPitch",-25);distance=(float)root.optDouble("cameraDistance",8);
                targetX=(float)root.optDouble("targetX",0);targetY=(float)root.optDouble("targetY",0);targetZ=(float)root.optDouble("targetZ",0);
            }catch(Exception ignored){}
        }

        synchronized String exportObj() {
            StringBuilder b=new StringBuilder("# Neura3D Studio OBJ\n# Exported scene\n");
            int offset=1, index=0;
            for(SceneObject o:objects){
                MeshData m=meshes.get(o.type); if(m==null)continue;
                b.append("o ").append(o.type).append("_").append(index++).append("\n");
                float[] mm=matrixFor(o);
                for(int i=0;i<m.vertices.length;i+=3){
                    float[] v={m.vertices[i],m.vertices[i+1],m.vertices[i+2],1}, out=new float[4];
                    Matrix.multiplyMV(out,0,mm,0,v,0);
                    b.append(String.format(Locale.US,"v %.6f %.6f %.6f\n",out[0],out[1],out[2]));
                }
                for(int i=0;i<m.indices.length;i+=3){
                    int a=(m.indices[i]&0xffff)+offset, c=(m.indices[i+1]&0xffff)+offset, d=(m.indices[i+2]&0xffff)+offset;
                    b.append("f ").append(a).append(' ').append(c).append(' ').append(d).append("\n");
                }
                offset += m.vertices.length/3;
            }
            return b.toString();
        }

        private void drawObject(SceneObject o,boolean selected){
            MeshData mesh=meshes.get(o.type);if(mesh==null)return;
            float[] mm=matrixFor(o);
            Matrix.multiplyMM(mvp,0,vp,0,mm,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            if(selected)GLES20.glUniform4f(uColor,0.28f,0.68f,1f,1);
            else if("sphere".equals(o.type))GLES20.glUniform4f(uColor,0.72f,0.42f,0.94f,1);
            else if("cylinder".equals(o.type))GLES20.glUniform4f(uColor,0.95f,0.58f,0.25f,1);
            else GLES20.glUniform4f(uColor,0.62f,0.68f,0.78f,1);
            mesh.vb.position(0);mesh.ib.position(0);
            GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,mesh.vb);
            GLES20.glDrawElements(GLES20.GL_TRIANGLES,mesh.indices.length,GLES20.GL_UNSIGNED_SHORT,mesh.ib);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private float[] matrixFor(SceneObject o){
            float[] mm=new float[16];Matrix.setIdentityM(mm,0);
            Matrix.translateM(mm,0,o.x,o.y,o.z);
            Matrix.rotateM(mm,0,o.ry,0,1,0);Matrix.rotateM(mm,0,o.rx,1,0,0);Matrix.rotateM(mm,0,o.rz,0,0,1);
            Matrix.scaleM(mm,0,o.sx,o.sy,o.sz);return mm;
        }

        private void drawGrid(){
            Matrix.setIdentityM(model,0);Matrix.multiplyMM(mvp,0,vp,0,model,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            GLES20.glUniform4f(uColor,0.18f,0.21f,0.27f,1);
            grid.position(0);GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,grid);
            GLES20.glDrawArrays(GLES20.GL_LINES,0,gridCount);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private void drawGizmo(){
            SceneObject o=selected(); if(o==null)return;
            float s=.8f*Math.max(1,o.sx);
            float[] v={o.x,o.y,o.z,o.x+s,o.y,o.z, o.x,o.y,o.z,o.x,o.y+s,o.z, o.x,o.y,o.z,o.x,o.y,o.z+s};
            FloatBuffer fb=ByteBuffer.allocateDirect(v.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();fb.put(v).position(0);
            Matrix.setIdentityM(model,0);Matrix.multiplyMM(mvp,0,vp,0,model,0);
            GLES20.glUniformMatrix4fv(uMvp,1,false,mvp,0);
            GLES20.glEnableVertexAttribArray(aPos);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);
            GLES20.glLineWidth(4);
            GLES20.glUniform4f(uColor,1,.25f,.25f,1);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            GLES20.glUniform4f(uColor,.25f,1,.35f,1);fb.position(6);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            fb.position(12);GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,fb);GLES20.glUniform4f(uColor,.25f,.55f,1,1);GLES20.glDrawArrays(GLES20.GL_LINES,0,2);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private void makeGrid(){
            ArrayList<Float> a=new ArrayList<>();int n=12;float size=12;
            for(int i=-n;i<=n;i++){
                float p=i;
                Collections.addAll(a,-size,0f,p,size,0f,p,p,0f,-size,p,0f,size);
            }
            float[] v=new float[a.size()];for(int i=0;i<v.length;i++)v[i]=a.get(i);
            grid=ByteBuffer.allocateDirect(v.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();grid.put(v).position(0);
            gridCount=v.length/3;
        }

        private static MeshData makeCube(){
            float h=.5f;
            float[] v={-h,-h,-h, h,-h,-h, h,h,-h, -h,h,-h, -h,-h,h, h,-h,h, h,h,h, -h,h,h};
            short[] i={0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,1,2,6,1,6,5,0,4,7,0,7,3};
            return new MeshData(v,i);
        }

        private static MeshData makeSphere(int lat,int lon){
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

        private static MeshData makeCylinder(int seg){
            ArrayList<Float> v=new ArrayList<>();ArrayList<Short> idx=new ArrayList<>();
            v.add(0f);v.add(.5f);v.add(0f);v.add(0f);v.add(-.5f);v.add(0f);
            for(int i=0;i<seg;i++){
                double a=2*Math.PI*i/seg;float x=(float)(.5*Math.cos(a)),z=(float)(.5*Math.sin(a));
                v.add(x);v.add(.5f);v.add(z);v.add(x);v.add(-.5f);v.add(z);
            }
            for(int i=0;i<seg;i++){
                int ni=(i+1)%seg; short ti=(short)(2+i*2), bi=(short)(ti+1), tn=(short)(2+ni*2), bn=(short)(tn+1);
                idx.add((short)0);idx.add(tn);idx.add(ti);
                idx.add((short)1);idx.add(bi);idx.add(bn);
                idx.add(ti);idx.add(tn);idx.add(bi);
                idx.add(tn);idx.add(bn);idx.add(bi);
            }
            float[] va=new float[v.size()];for(int i=0;i<va.length;i++)va[i]=v.get(i);
            short[] ia=new short[idx.size()];for(int i=0;i<ia.length;i++)ia[i]=idx.get(i);
            return new MeshData(va,ia);
        }

        private static int createProgram(String vs,String fs){
            int v=shader(GLES20.GL_VERTEX_SHADER,vs), f=shader(GLES20.GL_FRAGMENT_SHADER,fs);
            int p=GLES20.glCreateProgram();GLES20.glAttachShader(p,v);GLES20.glAttachShader(p,f);GLES20.glLinkProgram(p);
            int[] ok=new int[1];GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
            if(ok[0]==0)throw new RuntimeException(GLES20.glGetProgramInfoLog(p));
            GLES20.glDeleteShader(v);GLES20.glDeleteShader(f);return p;
        }
        private static int shader(int type,String src){
            int s=GLES20.glCreateShader(type);GLES20.glShaderSource(s,src);GLES20.glCompileShader(s);
            int[] ok=new int[1];GLES20.glGetShaderiv(s,GLES20.GL_COMPILE_STATUS,ok,0);
            if(ok[0]==0)throw new RuntimeException(GLES20.glGetShaderInfoLog(s));
            return s;
        }
    }
}
