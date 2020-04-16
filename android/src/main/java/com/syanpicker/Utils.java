package com.syanpicker;

import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore;

public class Utils {
    public static String getPathFromURI(Context context, String contentUri) {
        if (contentUri.indexOf("file://") > -1) {
            return contentUri;
        }

        Cursor cursor = null;

        try {
            String[] proj = {MediaStore.Images.Media.DATA};
            cursor = context.getContentResolver().query(Uri.parse(contentUri), proj, null, null, null);
            int column_index = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
            cursor.moveToFirst();
            return cursor.getString(column_index);
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }
    }
}
