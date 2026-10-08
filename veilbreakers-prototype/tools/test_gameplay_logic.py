#!/usr/bin/env python3
"""Run real campaign/collision/locomotion code on a JVM, with graphics-only stubs.

The stubs let VarynMap's actual collision/interaction methods run independently
of Android. They do not simulate or validate Canvas rendering; the emulator job
provides that evidence. No dependency downloads or phone mutations are performed.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
JAVA = ROOT / "app/src/main/java/com/veilbreakers/prototype"

STUBS = {
    "android/content/SharedPreferences.java": """package android.content;
public interface SharedPreferences {
 boolean contains(String key); boolean getBoolean(String key, boolean fallback);
 int getInt(String key, int fallback); Editor edit();
 interface Editor { Editor putInt(String key,int value); Editor putBoolean(String key,boolean value);
 Editor clear(); void apply(); }
}""",
    "android/graphics/RectF.java": """package android.graphics;
public class RectF { public float left,top,right,bottom;
 public RectF() {} public RectF(float l,float t,float r,float b) { set(l,t,r,b); }
 public void set(float l,float t,float r,float b) { left=l;top=t;right=r;bottom=b; }
}""",
    "android/graphics/Paint.java": """package android.graphics;
public class Paint { public static final int ANTI_ALIAS_FLAG=1,FILTER_BITMAP_FLAG=2;
 public enum Style {FILL,STROKE} public enum Align {CENTER}
 public Paint(int flags) {} public void setAlpha(int a) {} public void setColor(int c) {}
 public void setShader(Shader s) {} public void setStrokeWidth(float w) {} public void setStyle(Style s) {}
 public void setTextAlign(Align a) {} public void setTextSize(float s) {} public void setTypeface(Typeface t) {}
}""",
    "android/graphics/Shader.java": """package android.graphics;
public class Shader { public enum TileMode {CLAMP} }""",
    "android/graphics/LinearGradient.java": """package android.graphics;
public class LinearGradient extends Shader { public LinearGradient(Object... values) {} }""",
    "android/graphics/RadialGradient.java": """package android.graphics;
public class RadialGradient extends Shader { public RadialGradient(Object... values) {} }""",
    "android/graphics/Typeface.java": """package android.graphics;
public class Typeface { public static final Typeface SERIF=new Typeface(); public static final int NORMAL=0;
 public static Typeface create(Typeface family,int style) { return new Typeface(); } }""",
    "android/graphics/Color.java": """package android.graphics;
public class Color { public static final int TRANSPARENT=0;
 public static int rgb(int r,int g,int b) { return argb(255,r,g,b); }
 public static int argb(int a,int r,int g,int b) { return (a<<24)|(r<<16)|(g<<8)|b; } }""",
    "android/graphics/Bitmap.java": """package android.graphics;
public class Bitmap { public enum Config {ARGB_8888} private boolean recycled;
 public static Bitmap createBitmap(int w,int h,Config config) { return new Bitmap(); }
 public boolean isRecycled() {return recycled;} public void recycle() {recycled=true;} }""",
    "android/graphics/Path.java": """package android.graphics;
public class Path { public void reset() {} public void close() {}
 public void moveTo(float x,float y) {} public void lineTo(float x,float y) {} }""",
    "android/graphics/Canvas.java": """package android.graphics;
public class Canvas { public Canvas(Bitmap bitmap) {} public int getWidth() {return 1280;}
 public int getHeight() {return 720;} public void drawBitmap(Object... values) {}
 public void drawArc(Object... values) {} public void drawCircle(Object... values) {}
 public void drawLine(Object... values) {} public void drawOval(Object... values) {}
 public void drawPath(Object... values) {} public void drawRect(Object... values) {}
 public void drawRoundRect(Object... values) {} public void drawText(Object... values) {} }""",
}


def main():
    for program in ("javac", "java"):
        if not shutil.which(program):
            raise SystemExit(f"{program} is required: run this check with JDK 17 (as configured in CI)")
    with tempfile.TemporaryDirectory(prefix="veilbreakers-logic-") as directory:
        work = Path(directory)
        sources = []
        for name, content in STUBS.items():
            path = work / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            sources.append(path)
        sources.extend(JAVA / name for name in ("StoryState.java", "VarynMap.java", "LocomotionCycle.java"))
        sources.append(ROOT / "tools/GameplayLogicTest.java")
        classes = work / "classes"
        classes.mkdir()
        subprocess.run(["javac", "-encoding", "UTF-8", "-source", "8", "-target", "8",
                        "-d", str(classes), *map(str, sources)], check=True)
        subprocess.run(["java", "-cp", str(classes), "com.veilbreakers.prototype.GameplayLogicTest"], check=True)


if __name__ == "__main__":
    main()
