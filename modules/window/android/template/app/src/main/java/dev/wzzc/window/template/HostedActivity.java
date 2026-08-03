package dev.wzzc.window.template;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.Looper;
import android.util.Log;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.FrameLayout;

/**
 * Minimal Activity entry for the window hosted backend.
 * Lifecycle and surface/input events are forwarded to native HostCmd via JNI.
 * No moui_shell embedding inject APIs.
 */
public final class HostedActivity extends Activity implements SurfaceHolder.Callback {
  private static final String TAG = "WindowHosted";
  private SurfaceView surfaceView;
  private volatile boolean statusBarImmersive;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    Log.i(TAG, "window hosted template onCreate");
    try {
      String lib = "window_android_app";
      ApplicationInfo info =
          getPackageManager().getApplicationInfo(getPackageName(), PackageManager.GET_META_DATA);
      if (info.metaData != null) {
        String named = info.metaData.getString("dev.wzzc.window.NATIVE_LIB");
        if (named != null && !named.isEmpty()) {
          lib = named;
        }
      }
      System.loadLibrary(lib);
      Log.i(TAG, "loaded native library=" + lib);
    } catch (Throwable error) {
      Log.e(TAG, "native library load failed", error);
    }

    FrameLayout root = new FrameLayout(this);
    SurfaceView view = new SurfaceView(this);
    view.getHolder().addCallback(this);
    view.setOnTouchListener(
        new View.OnTouchListener() {
          @Override
          public boolean onTouch(View v, MotionEvent event) {
            dispatchTouch(event);
            return true;
          }
        });
    root.addView(
        view,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    setContentView(root);
    surfaceView = view;
    try {
      nativeOnHostCreate();
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnHostCreate failed", error);
    }
  }

  @Override
  protected void onResume() {
    super.onResume();
    try {
      nativeOnHostResume();
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnHostResume failed", error);
    }
  }

  @Override
  protected void onPause() {
    try {
      nativeOnHostPause();
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnHostPause failed", error);
    }
    super.onPause();
  }

  @Override
  protected void onDestroy() {
    try {
      nativeOnHostDestroy();
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnHostDestroy failed", error);
    }
    super.onDestroy();
  }

  /**
   * Applies the app-selected status-bar layout mode without hiding either
   * system bar. The native host calls this from the MoonBit entry thread;
   * Android window mutations are marshalled back to the UI thread here.
   */
  public void applyStatusBarImmersive(final boolean immersive) {
    Runnable update =
        new Runnable() {
          @Override
          public void run() {
            statusBarImmersive = immersive;
            Window window = getWindow();
            View decor = window.getDecorView();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
              window.setDecorFitsSystemWindows(!immersive);
            }
            int flags = decor.getSystemUiVisibility();
            if (immersive) {
              flags |= View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
              flags |= View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
              flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
              window.setStatusBarColor(Color.TRANSPARENT);
            } else {
              flags &= ~View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN;
              flags &= ~View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
              flags &= ~View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
              window.setStatusBarColor(Color.BLACK);
            }
            decor.setSystemUiVisibility(flags);
          }
        };
    if (Looper.myLooper() == Looper.getMainLooper()) {
      update.run();
    } else {
      runOnUiThread(update);
    }
  }

  @Override
  public void surfaceCreated(SurfaceHolder holder) {
    // Wait for surfaceChanged for valid size.
  }

  @Override
  public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
    try {
      nativeOnSurfaceChanged(holder.getSurface(), width, height);
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnSurfaceChanged failed", error);
    }
  }

  @Override
  public void surfaceDestroyed(SurfaceHolder holder) {
    try {
      nativeOnSurfaceDestroyed();
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnSurfaceDestroyed failed", error);
    }
  }

  private void dispatchTouch(MotionEvent event) {
    int action;
    switch (event.getActionMasked()) {
      case MotionEvent.ACTION_DOWN:
      case MotionEvent.ACTION_POINTER_DOWN:
        action = 1;
        break;
      case MotionEvent.ACTION_UP:
      case MotionEvent.ACTION_POINTER_UP:
      case MotionEvent.ACTION_CANCEL:
        action = 2;
        break;
      default:
        action = 0;
        break;
    }
    try {
      nativeOnPointer(action, event.getX(), event.getY());
    } catch (Throwable error) {
      Log.e(TAG, "nativeOnPointer failed", error);
    }
  }

  private native void nativeOnHostCreate();

  private native void nativeOnHostResume();

  private native void nativeOnHostPause();

  private native void nativeOnHostDestroy();

  private native void nativeOnSurfaceChanged(Surface surface, int width, int height);

  private native void nativeOnSurfaceDestroyed();

  private native void nativeOnPointer(int action, float x, float y);
}
