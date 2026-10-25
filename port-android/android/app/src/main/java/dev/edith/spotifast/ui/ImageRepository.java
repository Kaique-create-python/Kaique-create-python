package dev.edith.spotifast.ui;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.widget.ImageView;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.resource.bitmap.RoundedCorners;
import com.bumptech.glide.load.resource.bitmap.CenterCrop;
import com.bumptech.glide.load.resource.drawable.DrawableTransitionOptions;

public final class ImageRepository {
    public static void load(Activity activity,String url,ImageView view,int pixels){
        view.setScaleType(ImageView.ScaleType.CENTER_CROP);
        com.bumptech.glide.RequestBuilder<android.graphics.drawable.Drawable> request=Glide.with(activity).load(url.isEmpty()?null:url).override(pixels,pixels);
        if(activity.getPreferences(android.content.Context.MODE_PRIVATE).getBoolean("visual_effects",true))request=request.transition(DrawableTransitionOptions.withCrossFade(160));
        request
            .placeholder(new ColorDrawable(Color.rgb(40,51,55))).error(new ColorDrawable(Color.rgb(40,51,55)))
            .transform(new CenterCrop(),new RoundedCorners(16)).into(view);
    }
}

