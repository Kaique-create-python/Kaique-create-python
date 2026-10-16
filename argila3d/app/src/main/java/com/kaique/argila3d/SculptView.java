package com.kaique.argila3d;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;

public final class SculptView extends View {
    public enum Mode { SCULPT, VERTEX, EDGE, FACE, ORBIT }
    public enum Brush { RAISE, LOWER, INFLATE, SMOOTH }
    public Mode mode=Mode.SCULPT;
    public Brush brush=Brush.RAISE;
    public ClayMesh mesh;
    private Runnable listener;
    private final Paint ink=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path=new Path();
    private final ArrayDeque<String> history=new ArrayDeque<>();
    private final float density;
    private float yaw=0.42f,pitch=-0.2f,zoom=1f,radiusPx,strength=0.06f;
    private float lastX,lastY,oldPinch;
    private boolean touching=false,multi=false;
    private int selected=-1;
    private float[][] screen=new float[0][3],camera=new float[0][3];
    private boolean[] facing=new boolean[0];
    private final ArrayList<Face> drawFaces=new ArrayList<>();

    private static class Face {
        int index;
        float depth,light;
        Face(int i,float d,float l){index=i;depth=d;light=l;}
    }

    public SculptView(Context ctx){
        super(ctx);
        density=getResources().getDisplayMetrics().density;
        radiusPx=100*density;
        setLayerType(View.LAYER_TYPE_SOFTWARE,null);
    }
    public void setOnChanged(Runnable l){listener=l;}
    private void notifyChanged(){invalidate();if(listener!=null)listener.run();}
    public void setMesh(ClayMesh m){mesh=m;selected=-1;notifyChanged();}
    public void setMode(Mode m){mode=m;selected=-1;invalidate();}
    public void setBrush(Brush b){brush=b;invalidate();}
    public void setRadiusDp(float v){radiusPx=v*density;invalidate();}
    public void setStrength(float v){strength=v;}
    public void resetCamera(){yaw=.42f;pitch=-.2f;zoom=1f;invalidate();}
    public void remember(){
        if(mesh==null)return;
        if(history.size()>=16)history.removeFirst();
        history.addLast(mesh.write(false));
    }
    public boolean undo(){
        if(history.isEmpty())return false;
        try{setMesh(ClayMesh.read(history.removeLast()));return true;}
        catch(Exception ex){return false;}
    }

    private float scale(){return Math.min(getWidth(),getHeight())*.38f*zoom;}
    private float[] rotate(float x,float y,float z){
        float a=(float)Math.cos(yaw),b=(float)Math.sin(yaw);
        float c=(float)Math.cos(pitch),d=(float)Math.sin(pitch);
        float tx=a*x+b*z,tz=-b*x+a*z;
        return new float[]{tx,c*y-d*tz,d*y+c*tz};
    }
    private float[] unrotate(float x,float y,float z){
        float a=(float)Math.cos(yaw),b=(float)Math.sin(yaw);
        float c=(float)Math.cos(pitch),d=(float)Math.sin(pitch);
        float ty=c*y+d*z,tz=-d*y+c*z;
        return new float[]{a*x-b*tz,ty,b*x+a*tz};
    }

    private void recompute(){
        if(mesh==null)return;
        int count=mesh.vertices.size();
        if(screen.length!=count){
            screen=new float[count][3];camera=new float[count][3];facing=new boolean[count];
        }
        Arrays.fill(facing,false);
        float s=scale(),cx=getWidth()/2f,cy=getHeight()/2f;
        for(int i=0;i<count;i++){
            float[] v=mesh.vertices.get(i),t=rotate(v[0],v[1],v[2]);
            camera[i]=t;
            screen[i][0]=cx+t[0]*s;
            screen[i][1]=cy-t[1]*s;
            screen[i][2]=t[2];
        }
        drawFaces.clear();
        for(int i=0;i<mesh.faces.size();i++){
            int[] f=mesh.faces.get(i);
            float[] a=camera[f[0]],b=camera[f[1]],c=camera[f[2]];
            float ux=b[0]-a[0],uy=b[1]-a[1],uz=b[2]-a[2];
            float vx=c[0]-a[0],vy=c[1]-a[1],vz=c[2]-a[2];
            float nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;
            if(nz<=0.00001f)continue;
            float len=(float)Math.sqrt(nx*nx+ny*ny+nz*nz);
            float light=Math.max(0f,(nx*.35f+ny*.6f+nz*.7f)/Math.max(.00001f,len));
            drawFaces.add(new Face(i,(a[2]+b[2]+c[2])/3f,light));
            facing[f[0]]=true;facing[f[1]]=true;facing[f[2]]=true;
        }
        Collections.sort(drawFaces,(a,b)->Float.compare(a.depth,b.depth));
    }

    @Override protected void onDraw(Canvas canvas){
        super.onDraw(canvas);
        canvas.drawColor(0xFF111C28);
        ink.setColor(0xFF223443);ink.setStrokeWidth(density);ink.setStyle(Paint.Style.STROKE);
        float cx=getWidth()/2f,cy=getHeight()/2f;
        for(int n=-6;n<=6;n++){
            float pos=n*38*density;
            canvas.drawLine(cx+pos,0,cx+pos,getHeight(),ink);
            canvas.drawLine(0,cy+pos,getWidth(),cy+pos,ink);
        }
        if(mesh==null)return;
        recompute();
        ink.setStyle(Paint.Style.FILL);
        for(Face f:drawFaces){
            int[] tri=mesh.faces.get(f.index);
            path.reset();
            path.moveTo(screen[tri[0]][0],screen[tri[0]][1]);
            path.lineTo(screen[tri[1]][0],screen[tri[1]][1]);
            path.lineTo(screen[tri[2]][0],screen[tri[2]][1]);path.close();
            float l=.38f+.62f*f.light;
            ink.setColor(Color.rgb((int)(18+100*l),(int)(20+169*l),(int)(20+177*l)));
            canvas.drawPath(path,ink);
            if(mode==Mode.FACE && selected==f.index){
                ink.setColor(0x99FFCF74);canvas.drawPath(path,ink);
            }
        }
        if(mode==Mode.VERTEX || mode==Mode.EDGE || mode==Mode.FACE){
            ink.setStyle(Paint.Style.STROKE);ink.setStrokeWidth(1.1f*density);
            ink.setColor(0xB0183847);
            for(Face vf:drawFaces){
                int[] tri=mesh.faces.get(vf.index);
                path.reset();path.moveTo(screen[tri[0]][0],screen[tri[0]][1]);
                path.lineTo(screen[tri[1]][0],screen[tri[1]][1]);
                path.lineTo(screen[tri[2]][0],screen[tri[2]][1]);path.close();
                canvas.drawPath(path,ink);
            }
            ink.setStyle(Paint.Style.FILL);
            if(mode==Mode.VERTEX){
                for(int i=0;i<screen.length;i++)if(facing[i]){
                    ink.setColor(i==selected?0xFFFFD57C:0xFFE9F5F4);
                    canvas.drawCircle(screen[i][0],screen[i][1],(i==selected?5:2.8f)*density,ink);
                }
            }else if(mode==Mode.EDGE && selected>=0 && selected<mesh.edges.size()){
                int[] edge=mesh.edges.get(selected);
                ink.setColor(0xFFFFD57C);ink.setStrokeWidth(4*density);
                canvas.drawLine(screen[edge[0]][0],screen[edge[0]][1],
                                screen[edge[1]][0],screen[edge[1]][1],ink);
            }
        }
        if(touching && !multi && mode==Mode.SCULPT){
            ink.setStyle(Paint.Style.STROKE);ink.setStrokeWidth(2*density);
            ink.setColor(0xCC50E0B7);canvas.drawCircle(lastX,lastY,radiusPx,ink);
        }
        ink.setStyle(Paint.Style.FILL);ink.setColor(0xFFB8CFD9);
        ink.setTextSize(12*density);
        canvas.drawText(mode==Mode.SCULPT?"PINCEL: "+brush.name():"MODO: "+mode.name(),
                        12*density,22*density,ink);
    }

    private boolean inside(float[] a,float[] b,float[] c,float x,float y){
        float den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
        if(Math.abs(den)<.001f)return false;
        float u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(y-c[1]))/den;
        float v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(y-c[1]))/den;
        return u>=-.002f && v>=-.002f && (u+v)<=1.002f;
    }

    private int pickedFace(float x,float y){
        int chosen=-1;float near=Float.NEGATIVE_INFINITY;
        for(Face face:drawFaces){
            int[] tri=mesh.faces.get(face.index);
            if(face.depth>=near && inside(screen[tri[0]],screen[tri[1]],screen[tri[2]],x,y)){
                chosen=face.index;near=face.depth;
            }
        }
        return chosen;
    }

    private int pickedVertex(float x,float y){
        int found=-1;float best=18*18*density*density;
        for(int i=0;i<screen.length;i++)if(facing[i]){
            float dx=screen[i][0]-x,dy=screen[i][1]-y;
            float r=dx*dx+dy*dy;
            if(r<best){best=r;found=i;}
        }
        return found;
    }

    private int pickedEdge(float x,float y){
        int found=-1;float best=15*15*density*density;
        for(int i=0;i<mesh.edges.size();i++){
            int[] edge=mesh.edges.get(i);
            if(!facing[edge[0]]||!facing[edge[1]])continue;
            float[] a=screen[edge[0]],b=screen[edge[1]];
            float dx=b[0]-a[0],dy=b[1]-a[1];
            float len=dx*dx+dy*dy;
            float t=len<.001f?0:Math.max(0,Math.min(1,
                          ((x-a[0])*dx+(y-a[1])*dy)/len));
            float px=a[0]+t*dx-x,py=a[1]+t*dy-y;
            float r=px*px+py*py;
            if(r<best){best=r;found=i;}
        }
        return found;
    }

    private void moveSelection(float dx,float dy){
        if(selected<0)return;
        float s=Math.max(10,scale());
        float[] change=unrotate(dx/s,-dy/s,0);
        int[] ids;
        if(mode==Mode.VERTEX && selected<mesh.vertices.size())ids=new int[]{selected};
        else if(mode==Mode.EDGE && selected<mesh.edges.size())ids=mesh.edges.get(selected);
        else if(mode==Mode.FACE && selected<mesh.faces.size())ids=mesh.faces.get(selected);
        else return;
        for(int i:ids){
            float[] v=mesh.vertices.get(i);
            for(int k=0;k<3;k++)v[k]+=change[k];
        }
        notifyChanged();
    }

    private void sculpt(float x,float y){
        recompute();
        if(pickedFace(x,y)<0)return;
        float[][] normals=mesh.normals();
        float[][] next=new float[mesh.vertices.size()][3];
        boolean changed=false;
        for(int i=0;i<mesh.vertices.size();i++){
            float[] v=mesh.vertices.get(i);
            next[i]=Arrays.copyOf(v,3);
            if(!facing[i])continue;
            float dx=screen[i][0]-x,dy=screen[i][1]-y;
            float distance=(float)Math.sqrt(dx*dx+dy*dy);
            if(distance>radiusPx)continue;
            float falloff=(1-distance/radiusPx);
            float amp=strength*falloff*falloff;
            if(brush==Brush.SMOOTH){
                ArrayList<Integer> near=mesh.neighbors.get(i);
                if(near.isEmpty())continue;
                float[] average=new float[3];
                for(int id:near)for(int j=0;j<3;j++)average[j]+=mesh.vertices.get(id)[j];
                for(int j=0;j<3;j++)next[i][j]+=(average[j]/near.size()-v[j])*Math.min(1,amp*3);
            }else{
                float sign=brush==Brush.LOWER?-1:1;
                float[] normal=normals[i];
                if(brush==Brush.INFLATE){
                    float len=(float)Math.sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]);
                    if(len>.0001f)normal=new float[]{v[0]/len,v[1]/len,v[2]/len};
                }
                for(int j=0;j<3;j++)next[i][j]+=normal[j]*amp*sign;
            }
            changed=true;
        }
        if(changed){
            for(int i=0;i<next.length;i++)
                System.arraycopy(next[i],0,mesh.vertices.get(i),0,3);
            notifyChanged();
        }
    }

    private float pinch(MotionEvent e){
        return (float)Math.hypot(e.getX(1)-e.getX(0),e.getY(1)-e.getY(0));
    }

    @Override public boolean onTouchEvent(MotionEvent e){
        if(mesh==null)return false;
        int action=e.getActionMasked();
        if(action==MotionEvent.ACTION_DOWN){
            touching=true;multi=false;lastX=e.getX();lastY=e.getY();
            recompute();
            if(mode==Mode.VERTEX)selected=pickedVertex(lastX,lastY);
            else if(mode==Mode.EDGE)selected=pickedEdge(lastX,lastY);
            else if(mode==Mode.FACE)selected=pickedFace(lastX,lastY);
            else selected=-1;
            if(mode==Mode.SCULPT && pickedFace(lastX,lastY)>=0){
                remember();sculpt(lastX,lastY);
            }else if(selected>=0)remember();
            invalidate();return true;
        }
        if(action==MotionEvent.ACTION_POINTER_DOWN){
            multi=true;oldPinch=pinch(e);
            lastX=(e.getX(0)+e.getX(1))/2;
            lastY=(e.getY(0)+e.getY(1))/2;
            return true;
        }
        if(action==MotionEvent.ACTION_MOVE){
            if(e.getPointerCount()>=2){
                float x=(e.getX(0)+e.getX(1))/2,y=(e.getY(0)+e.getY(1))/2;
                yaw+=(x-lastX)/Math.max(1,getWidth())*3;
                pitch=Math.max(-1.45f,Math.min(1.45f,
                          pitch+(y-lastY)/Math.max(1,getHeight())*3));
                float now=pinch(e);
                if(oldPinch>10)zoom=Math.max(.28f,Math.min(3.5f,zoom*now/oldPinch));
                oldPinch=now;lastX=x;lastY=y;invalidate();return true;
            }
            if(multi)return true;
            float x=e.getX(),y=e.getY(),dx=x-lastX,dy=y-lastY;
            if(mode==Mode.ORBIT){
                yaw+=dx/Math.max(1,getWidth())*4;
                pitch=Math.max(-1.45f,Math.min(1.45f,
                          pitch+dy/Math.max(1,getHeight())*4));
                invalidate();
            }else if(mode==Mode.SCULPT){
                int steps=Math.max(1,Math.min(12,
                          (int)(Math.hypot(dx,dy)/Math.max(6,radiusPx*.2f))+1));
                for(int j=1;j<=steps;j++)
                    sculpt(lastX+dx*j/steps,lastY+dy*j/steps);
            }else moveSelection(dx,dy);
            lastX=x;lastY=y;invalidate();return true;
        }
        if(action==MotionEvent.ACTION_POINTER_UP){multi=true;return true;}
        if(action==MotionEvent.ACTION_UP || action==MotionEvent.ACTION_CANCEL){
            touching=false;multi=false;invalidate();return true;
        }
        return true;
    }
}
