package dev.edith.spotifast;

import android.app.Application;
import com.bumptech.glide.*;
import com.bumptech.glide.load.engine.cache.*;
import com.bumptech.glide.load.engine.bitmap_recycle.LruBitmapPool;

/** Explicit memory and disk bounds, independent of the Activity lifecycle. */
public final class SpotiFastApplication extends Application {
    @Override public void onCreate(){super.onCreate();
        int requested=getSharedPreferences("FreeMusicActivity",MODE_PRIVATE).getInt("image_cache_mb",64);
        int disk=Math.max(32,Math.min(128,requested));
        Glide.init(this,new GlideBuilder().setDiskCache(new InternalCacheDiskCacheFactory(this,disk*1024L*1024))
            .setMemoryCache(new LruResourceCache(12L*1024*1024)).setBitmapPool(new LruBitmapPool(8L*1024*1024)));
    }
}
