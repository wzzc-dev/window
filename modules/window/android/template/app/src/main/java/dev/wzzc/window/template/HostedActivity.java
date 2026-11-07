package dev.wzzc.window.template;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.os.Looper;
import android.util.Log;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
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
  private volatile java.util.ArrayList<A11yNode> a11yNodes =
      new java.util.ArrayList<A11yNode>();
  private volatile long a11yRootId;
  private volatile long a11yFocusedId;
  private volatile long a11yGeneration;
  private HostedA11yProvider a11yProvider;

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
    HostedSurfaceView view = new HostedSurfaceView(this);
    view.getHolder().addCallback(this);
    view.setFocusable(true);
    view.setFocusableInTouchMode(true);
    view.requestFocus();
    view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES);
    view.setAccessibilityDelegate(
        new View.AccessibilityDelegate() {
          @Override
          public android.view.accessibility.AccessibilityNodeProvider
              getAccessibilityNodeProvider(View host) {
            if (a11yProvider == null) {
              a11yProvider = new HostedA11yProvider(host);
            }
            return a11yProvider;
          }
        });
    view.setOnTouchListener(
        new View.OnTouchListener() {
          @Override
          public boolean onTouch(View v, MotionEvent event) {
            dispatchTouch(event);
            if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
              view.requestFocus();
            }
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

  /**
   * Writes plain text to the system clipboard. Called from the MoonBit
   * service thread through JNI; ClipboardManager is marshalled to the UI
   * thread with a latch so the native caller blocks until the result exists.
   */
  public boolean writeClipboard(final String text) {
    if (text == null || text.isEmpty()) {
      return false;
    }
    final java.util.concurrent.atomic.AtomicBoolean ok =
        new java.util.concurrent.atomic.AtomicBoolean(false);
    Runnable write =
        new Runnable() {
          @Override
          public void run() {
            try {
              android.content.ClipboardManager manager =
                  (android.content.ClipboardManager)
                      getSystemService(CLIPBOARD_SERVICE);
              if (manager != null) {
                manager.setPrimaryClip(
                    android.content.ClipData.newPlainText("moui", text));
                ok.set(true);
              }
            } catch (Throwable error) {
              Log.e(TAG, "clipboard write failed", error);
            }
          }
        };
    return runOnUiAndWait(write, ok);
  }

  /** Reads plain text from the system clipboard, or null when absent. */
  public String readClipboard() {
    final java.util.concurrent.atomic.AtomicReference<String> value =
        new java.util.concurrent.atomic.AtomicReference<String>(null);
    Runnable read =
        new Runnable() {
          @Override
          public void run() {
            try {
              android.content.ClipboardManager manager =
                  (android.content.ClipboardManager)
                      getSystemService(CLIPBOARD_SERVICE);
              if (manager != null && manager.hasPrimaryClip()) {
                android.content.ClipData clip = manager.getPrimaryClip();
                if (clip != null && clip.getItemCount() > 0) {
                  CharSequence text =
                      clip.getItemAt(0).coerceToText(HostedActivity.this);
                  if (text != null) {
                    value.set(text.toString());
                  }
                }
              }
            } catch (Throwable error) {
              Log.e(TAG, "clipboard read failed", error);
            }
          }
        };
    runOnUiAndWait(read, null);
    return value.get();
  }

  /**
   * Runs {@code action} on the UI thread and blocks the caller until it
   * finished. Deadlock-safe when already on the UI thread (runs inline).
   */
  private boolean runOnUiAndWait(
      Runnable action, java.util.concurrent.atomic.AtomicBoolean result) {
    java.util.concurrent.CountDownLatch latch =
        new java.util.concurrent.CountDownLatch(1);
    Runnable wrapped =
        new Runnable() {
          @Override
          public void run() {
            try {
              action.run();
            } finally {
              latch.countDown();
            }
          }
        };
    if (Looper.myLooper() == Looper.getMainLooper()) {
      wrapped.run();
    } else {
      runOnUiThread(wrapped);
      try {
        latch.await(2, java.util.concurrent.TimeUnit.SECONDS);
      } catch (InterruptedException error) {
        Thread.currentThread().interrupt();
        return false;
      }
    }
    return result == null ? true : result.get();
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

  /**
   * Surface view that acts as a text editor: the IME (and adb's
   * {@code input text}) deliver commits through its InputConnection.
   */
  private static final class HostedSurfaceView extends SurfaceView {
    private final HostedActivity activity;

    HostedSurfaceView(HostedActivity activity) {
      super(activity);
      this.activity = activity;
    }

    @Override
    public boolean onCheckIsTextEditor() {
      return true;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
      outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT;
      outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_FULLSCREEN;
      return new HostedInputConnection(this, activity);
    }
  }

  /**
   * Forwards IME commits and deletions to the native HostCmd queue. Commit
   * codepoints ride the KeyboardText channel; Backspace/Delete ride the
   * named-key channel so the hosted text field deletes instead of
   * inserting a control character.
   */
  private static final class HostedInputConnection extends BaseInputConnection {
    private final HostedActivity activity;

    HostedInputConnection(View target, HostedActivity activity) {
      super(target, true);
      this.activity = activity;
    }

    @Override
    public boolean commitText(CharSequence text, int newCursorPosition) {
      for (int index = 0; index < text.length(); index++) {
        activity.nativeOnKeyboardCodepoint(text.charAt(index));
      }
      return true;
    }

    @Override
    public boolean deleteSurroundingText(int beforeLength, int afterLength) {
      for (int index = 0; index < beforeLength; index++) {
        activity.nativeOnKeyboardKey(KeyEvent.KEYCODE_DEL, 1);
        activity.nativeOnKeyboardKey(KeyEvent.KEYCODE_DEL, 0);
      }
      return super.deleteSurroundingText(beforeLength, afterLength);
    }

    @Override
    public boolean sendKeyEvent(KeyEvent event) {
      activity.forwardKeyEvent(event);
      return true;
    }
  }

  /** Routes hardware/adb key events into the named-key channel. */
  @Override
  public boolean dispatchKeyEvent(KeyEvent event) {
    forwardKeyEvent(event);
    return super.dispatchKeyEvent(event);
  }

  private void forwardKeyEvent(KeyEvent event) {
    int action = event.getAction();
    if (action != KeyEvent.ACTION_DOWN && action != KeyEvent.ACTION_UP) {
      return;
    }
    int keyCode = event.getKeyCode();
    switch (keyCode) {
      case KeyEvent.KEYCODE_DEL:
      case KeyEvent.KEYCODE_FORWARD_DEL:
      case KeyEvent.KEYCODE_ENTER:
      case KeyEvent.KEYCODE_TAB:
      case KeyEvent.KEYCODE_ESCAPE:
      case KeyEvent.KEYCODE_DPAD_UP:
      case KeyEvent.KEYCODE_DPAD_DOWN:
      case KeyEvent.KEYCODE_DPAD_LEFT:
      case KeyEvent.KEYCODE_DPAD_RIGHT:
      case KeyEvent.KEYCODE_MOVE_HOME:
      case KeyEvent.KEYCODE_MOVE_END:
        try {
          nativeOnKeyboardKey(keyCode, action == KeyEvent.ACTION_DOWN ? 1 : 0);
        } catch (Throwable error) {
          Log.e(TAG, "nativeOnKeyboardKey failed", error);
        }
        return;
      default:
        if (action == KeyEvent.ACTION_UP) {
          int unicode = event.getUnicodeChar(event.getMetaState());
          if (unicode > 0) {
            try {
              nativeOnKeyboardCodepoint(unicode);
            } catch (Throwable error) {
              Log.e(TAG, "nativeOnKeyboardCodepoint failed", error);
            }
          }
        }
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

  private native void nativeOnKeyboardCodepoint(int codepoint);

  private native void nativeOnKeyboardKey(int keyCode, int pressed);

  /**
   * Receives the MoonBit-encoded semantics tree (see
   * moui/backend/android/android_accessibility.mbt). Header groups carry
   * "gen=&lt;n&gt;", root id, focused id; each node group carries eleven
   * \u001F-separated fields: id, parent, role, flags, left, top, right,
   * bottom, label, value, description. Groups are \u001E-separated.
   */
  public boolean publishAccessibility(String tree) {
    try {
      String[] groups = tree.split("\u001E");
      if (groups.length < 3) {
        return false;
      }
      long generation = Long.parseLong(groups[0].substring(4));
      long rootId = Long.parseLong(groups[1]);
      long focusedId = Long.parseLong(groups[2]);
      java.util.ArrayList<A11yNode> nodes = new java.util.ArrayList<A11yNode>();
      for (int i = 3; i < groups.length; i++) {
        if (groups[i].isEmpty()) {
          continue;
        }
        String[] f = groups[i].split("\u001F", 11);
        if (f.length < 11) {
          continue;
        }
        nodes.add(
            new A11yNode(
                Long.parseLong(f[0]),
                Long.parseLong(f[1]),
                Integer.parseInt(f[2]),
                Integer.parseInt(f[3]),
                Double.parseDouble(f[4]),
                Double.parseDouble(f[5]),
                Double.parseDouble(f[6]),
                Double.parseDouble(f[7]),
                f[8],
                f[9],
                f[10]));
      }
      this.a11yGeneration = generation;
      this.a11yRootId = rootId;
      this.a11yFocusedId = focusedId;
      this.a11yNodes = nodes;
      Log.i(TAG, "a11y published gen=" + generation + " nodes=" + nodes.size() + " root=" + rootId);
      if (surfaceView != null) {
        surfaceView.sendAccessibilityEvent(
            android.view.accessibility.AccessibilityEvent
                .TYPE_WINDOW_CONTENT_CHANGED);
      }
      return true;
    } catch (Throwable error) {
      Log.e(TAG, "a11y publish failed", error);
      return false;
    }
  }

  /** One projected semantics node (see android_accessibility.mbt). */
  private static final class A11yNode {
    final long id;
    final long parent;
    final int role;
    final int flags;
    final float left;
    final float top;
    final float right;
    final float bottom;
    final String label;
    final String value;
    final String description;

    A11yNode(
        long id,
        long parent,
        int role,
        int flags,
        double left,
        double top,
        double right,
        double bottom,
        String label,
        String value,
        String description) {
      this.id = id;
      this.parent = parent;
      this.role = role;
      this.flags = flags;
      this.left = (float) left;
      this.top = (float) top;
      this.right = (float) right;
      this.bottom = (float) bottom;
      this.label = label;
      this.value = value;
      this.description = description;
    }

    boolean enabled() {
      return (flags & 8) != 0;
    }

    boolean clickable() {
      return (flags & 16) != 0;
    }

    String displayText() {
      if (!label.isEmpty()) {
        return label;
      }
      if (!value.isEmpty()) {
        return value;
      }
      return description;
    }
  }

  /**
   * Maps the projected semantics tree onto virtual child views of the
   * hosting surface. ACTION_CLICK synthesizes a tap at the node center on
   * the existing pointer channel — the same "double-tap to activate"
   * interaction TalkBack falls back to for canvas-drawn content.
   */
  private final class HostedA11yProvider
      extends android.view.accessibility.AccessibilityNodeProvider {
    private static final int HOST_VIEW_ID = -1;
    private final View host;

    HostedA11yProvider(View host) {
      this.host = host;
    }

    private A11yNode findNode(long id) {
      java.util.ArrayList<A11yNode> nodes = a11yNodes;
      for (A11yNode node : nodes) {
        if (node.id == id) {
          return node;
        }
      }
      return null;
    }

    private int virtualId(long nodeId) {
      return (int) nodeId;
    }

    private Rect screenBounds(A11yNode node, int[] screenOffset) {
      float density = host.getResources().getDisplayMetrics().density;
      Rect bounds =
          new Rect(
              Math.round(node.left * density),
              Math.round(node.top * density),
              Math.round(node.right * density),
              Math.round(node.bottom * density));
      bounds.offset(screenOffset[0], screenOffset[1]);
      return bounds;
    }

    private String classNameFor(int role) {
      switch (role) {
        case 1:
          return "android.widget.Button";
        case 2:
        case 10:
        case 11:
          return "android.widget.TextView";
        case 3:
          return "android.widget.EditText";
        case 4:
          return "android.widget.CheckBox";
        case 5:
          return "android.widget.Switch";
        case 6:
          return "android.widget.SeekBar";
        case 7:
          return "android.widget.ListView";
        case 9:
          return "android.widget.ImageView";
        case 12:
          return "android.widget.ScrollView";
        default:
          return "android.view.View";
      }
    }

    @Override
    public AccessibilityNodeInfo createAccessibilityNodeInfo(int virtualViewId) {
      Log.i(TAG, "a11y nodeInfo request id=" + virtualViewId);
      int[] screenOffset = new int[2];
      host.getLocationOnScreen(screenOffset);
      if (virtualViewId == HOST_VIEW_ID) {
        AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain(host);
        // obtain(host) only sets the source; bounds/enabled/visible come from
        // the view's own initialization, which the provider path bypasses.
        host.onInitializeAccessibilityNodeInfo(info);
        for (A11yNode node : a11yNodes) {
          if (node.parent == 0) {
            info.addChild(host, virtualId(node.id));
          }
        }
        return info;
      }
      A11yNode node = findNode(virtualViewId);
      if (node == null) {
        Log.w(TAG, "a11y findNode miss id=" + virtualViewId + " nodes=" + a11yNodes.size());
        return null;
      }
      AccessibilityNodeInfo info =
          AccessibilityNodeInfo.obtain(host, virtualViewId);
      info.setClassName(classNameFor(node.role));
      info.setText(node.displayText());
      if (!node.description.isEmpty()) {
        info.setContentDescription(node.description);
      }
      info.setEnabled(node.enabled());
      info.setClickable(node.clickable());
      info.setFocusable(true);
      info.setFocused((node.flags & 1) != 0 || node.id == a11yFocusedId);
      info.setVisibleToUser(true);
      if (node.clickable()) {
        info.addAction(AccessibilityNodeInfo.ACTION_CLICK);
      }
      if (node.parent == 0) {
        info.setParent(host);
      } else {
        info.setParent(host, virtualId(node.parent));
      }
      java.util.ArrayList<A11yNode> nodes = a11yNodes;
      for (A11yNode child : nodes) {
        if (child.parent == node.id) {
          info.addChild(host, virtualId(child.id));
        }
      }
      info.setBoundsInScreen(screenBounds(node, screenOffset));
      Rect relative = screenBounds(node, screenOffset);
      relative.offset(-screenOffset[0], -screenOffset[1]);
      info.setBoundsInParent(relative);
      Log.i(
          TAG,
          "a11y node built id="
              + virtualViewId
              + " text="
              + node.displayText()
              + " screen="
              + relative);
      return info;
    }

    @Override
    public boolean performAction(
        int virtualViewId, int action, Bundle arguments) {
      A11yNode node = findNode(virtualViewId);
      if (node == null || action != AccessibilityNodeInfo.ACTION_CLICK) {
        return false;
      }
      if (!node.clickable() || !node.enabled()) {
        return false;
      }
      int[] screenOffset = new int[2];
      host.getLocationOnScreen(screenOffset);
      float x =
          (node.left + (node.right - node.left) / 2f)
                  * host.getResources().getDisplayMetrics().density
              - screenOffset[0];
      float y =
          (node.top + (node.bottom - node.top) / 2f)
                  * host.getResources().getDisplayMetrics().density
              - screenOffset[1];
      try {
        nativeOnPointer(1, x, y);
        nativeOnPointer(0, x, y);
        return true;
      } catch (Throwable error) {
        Log.e(TAG, "a11y activate failed", error);
        return false;
      }
    }
  }
}
