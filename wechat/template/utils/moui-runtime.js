// MoUI Runtime bridge for WeChat Mini Program.
// This file loads the MoonBit wasm-gc module and connects it to the
// Mini Program's Canvas 2D and event system.

let wasmInstance = null;
let canvasContext = null;
let canvasNode = null;
let isRunning = false;

// Dynamic screen dimensions (set before wasm init)
let screenWidth = 375;
let screenHeight = 812;
let screenPixelRatio = 2;

// Touch tracking for delta calculation
let lastTouchX = 0;
let lastTouchY = 0;
let pendingTouchMove = null;
let touchFrameScheduled = false;
let renderFrameId = null;

/**
 * Initialize the MoUI wasm runtime.
 * @param {string} canvasId - The canvas element ID.
 */
function initMoui(canvasId) {
  const query = wx.createSelectorQuery();
  return new Promise((resolve, reject) => {
    query.select('#' + canvasId)
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          reject(new Error('Canvas not found: ' + canvasId));
          return;
        }

        const canvas = res[0].node;
        canvasNode = canvas;
        canvasContext = canvas.getContext('2d');

        // Get dynamic screen dimensions
        const sysInfo = wx.getSystemInfoSync();
        const statusBarHeight = sysInfo.statusBarHeight || 0;
        screenWidth = res[0].width || sysInfo.windowWidth || 375;
        screenHeight = (res[0].height || sysInfo.windowHeight || 812) - statusBarHeight;
        screenPixelRatio = Math.min(sysInfo.pixelRatio || 2, 2);

        canvas.width = screenWidth * screenPixelRatio;
        canvas.height = screenHeight * screenPixelRatio;
        canvasContext.scale(screenPixelRatio, screenPixelRatio);

        console.log('[MoUI] Screen:', screenWidth, 'x', screenHeight, '@', screenPixelRatio, 'x', 'statusBar:', statusBarHeight);

        // Load wasm after canvas is ready
        loadWasmModule().then((instance) => {
          wasmInstance = instance;
          const exports = instance.exports;
          // MoonBit wasm uses _start as the entry point (calls main internally)
          if (exports._start) {
            console.log('[MoUI] Calling _start()...');
            exports._start();
            console.log('[MoUI] _start() returned');
          } else if (exports.main) {
            console.log('[MoUI] Calling main()...');
            exports.main();
            console.log('[MoUI] main() returned');
          } else {
            console.warn('[MoUI] No entry point found in:', Object.keys(exports));
          }
          console.log('[MoUI] Runtime started');
          resolve();
        }).catch(reject);
      });
  });
}

/**
 * Load the MoonBit wasm-gc module.
 */
function loadWasmModule() {
  const wasmPath = 'moui/moui.wasm';

  try {
    const imports = createWasmImports();
    console.log('[MoUI] Wasm imports:', Object.keys(imports));
    // WeChat Mini Program uses WXWebAssembly instead of the standard WebAssembly.
    // WXWebAssembly.instantiate expects a file path, not an ArrayBuffer.
    const WASM = typeof WXWebAssembly !== 'undefined' ? WXWebAssembly : WebAssembly;
    console.log('[MoUI] Using WASM:', WASM === WXWebAssembly ? 'WXWebAssembly' : 'WebAssembly');
    console.log('[MoUI] Loading wasm from:', wasmPath);
    return WASM.instantiate(wasmPath, imports).then((result) => {
      console.log('[MoUI] Wasm module loaded');
      console.log('[MoUI] Wasm exports:', Object.keys(result.instance.exports));
      return result.instance;
    }).catch((err) => {
      console.error('[MoUI] Wasm instantiate failed:', err);
      console.error('[MoUI] Error name:', err.name);
      console.error('[MoUI] Error message:', err.message);
      throw err;
    });
  } catch (err) {
    console.error('[MoUI] Failed to load wasm:', err);
    return Promise.reject(err);
  }
}

/**
 * Create the WebAssembly import object.
 */
function createWasmImports() {
  return {
    canvas2d: {
      screen_width: () => screenWidth,
      screen_height: () => screenHeight,
      pixel_ratio: () => screenPixelRatio,
      begin_frame: canvas2dBeginFrame,
      save: canvas2dSave,
      restore: canvas2dRestore,
      fill_rect: canvas2dFillRect,
      fill_rounded_rect: canvas2dFillRoundedRect,
      stroke_rounded_rect: canvas2dStrokeRoundedRect,
      draw_text: canvas2dDrawText,
      set_transform: canvas2dSetTransform,
      translate: canvas2dTranslate,
      clip_rect: canvas2dClipRect,
      clip_rounded_rect: canvas2dClipRoundedRect,
      set_global_alpha: canvas2dSetGlobalAlpha,
      stroke_rect: canvas2dStrokeRect,
      draw_shadow: canvas2dDrawShadow,
      draw_path: canvas2dDrawPath,
      measure_text_width: canvas2dMeasureTextWidth,
    },
  };
}

/**
 * Begin a new frame — clear the canvas.
 */
function canvas2dBeginFrame(width, height) {
  if (!canvasContext) return;
  canvasContext.clearRect(0, 0, width, height);
}

/**
 * Save the current canvas state.
 */
function canvas2dSave() {
  if (!canvasContext) return;
  canvasContext.save();
}

/**
 * Restore the previously saved canvas state.
 */
function canvas2dRestore() {
  if (!canvasContext) return;
  canvasContext.restore();
}

/**
 * Fill a rectangle with the given color (r,g,b,a in 0.0–1.0 range).
 */
function canvas2dFillRect(x, y, w, h, r, g, b, a) {
  if (!canvasContext) return;
  canvasContext.fillStyle = colorToString(r, g, b, a);
  canvasContext.fillRect(x, y, w, h);
}

/**
 * Fill a rounded rectangle with the given color.
 */
function canvas2dFillRoundedRect(x, y, w, h, radius, r, g, b, a) {
  if (!canvasContext) return;
  canvasContext.fillStyle = colorToString(r, g, b, a);
  canvasContext.beginPath();
  roundedRectPath(canvasContext, x, y, w, h, radius);
  canvasContext.fill();
}

/**
 * Stroke a rounded rectangle with the given color and line width.
 */
function canvas2dStrokeRoundedRect(x, y, w, h, radius, strokeWidth, r, g, b, a) {
  if (!canvasContext) return;
  canvasContext.strokeStyle = colorToString(r, g, b, a);
  canvasContext.lineWidth = strokeWidth;
  canvasContext.beginPath();
  roundedRectPath(canvasContext, x, y, w, h, radius);
  canvasContext.stroke();
}

/**
 * Draw text with character codes passed as individual Int parameters.
 * c0-c19: character code points (0 means unused)
 * len: actual text length
 */
function canvas2dDrawText(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9,
                          c10, c11, c12, c13, c14, c15, c16, c17, c18, c19,
                          len, x, y, w, h, fontSize, fontWeight, r, g, b, a, align) {
  if (!canvasContext) return;
  // Reconstruct the text string from character codes
  var codes = [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9,
               c10, c11, c12, c13, c14, c15, c16, c17, c18, c19];
  var text = '';
  for (var i = 0; i < len && i < codes.length; i++) {
    if (codes[i] > 0) {
      text += String.fromCharCode(codes[i]);
    }
  }
  canvasContext.fillStyle = colorToString(r, g, b, a);
  canvasContext.font = `${fontWeight} ${fontSize}px system-ui, sans-serif`;
  canvasContext.textBaseline = 'top';
  var textAlign = 'start';
  if (align === 1) textAlign = 'center';
  else if (align === 2) textAlign = 'end';
  canvasContext.textAlign = textAlign;
  var textX = x;
  if (align === 1) textX = x + w / 2;
  else if (align === 2) textX = x + w;
  // Center text vertically: use 'top' baseline + manual offset
  // fontSize is the em-square height; glyphs sit slightly below the top
  var textY = y + (h - fontSize) / 2 + fontSize * 0.05;
  canvasContext.fillText(text, textX, textY);
}

/**
 * Set the full transform matrix (a, b, c, d, tx, ty).
 */
function canvas2dSetTransform(a, b, c, d, tx, ty) {
  if (!canvasContext) return;
  canvasContext.setTransform(a, b, c, d, tx, ty);
}

/**
 * Translate the canvas origin.
 */
function canvas2dTranslate(x, y) {
  if (!canvasContext) return;
  canvasContext.translate(x, y);
}

/**
 * Set a rectangular clipping region.
 */
function canvas2dClipRect(x, y, w, h) {
  if (!canvasContext) return;
  canvasContext.beginPath();
  canvasContext.rect(x, y, w, h);
  canvasContext.clip();
}

/**
 * Set a rounded rectangular clipping region.
 */
function canvas2dClipRoundedRect(x, y, w, h, radius) {
  if (!canvasContext) return;
  canvasContext.beginPath();
  roundedRectPath(canvasContext, x, y, w, h, radius);
  canvasContext.clip();
}

/**
 * Set the global alpha (opacity) for subsequent drawing operations.
 */
function canvas2dSetGlobalAlpha(alpha) {
  if (!canvasContext) return;
  canvasContext.globalAlpha = alpha;
}

/**
 * Stroke a rectangle with the given color and line width.
 */
function canvas2dStrokeRect(x, y, w, h, strokeWidth, r, g, b, a) {
  if (!canvasContext) return;
  canvasContext.strokeStyle = colorToString(r, g, b, a);
  canvasContext.lineWidth = strokeWidth;
  canvasContext.strokeRect(x, y, w, h);
}

/**
 * Draw a shadow (rounded rect with shadow effect).
 */
function canvas2dDrawShadow(x, y, w, h, radius, offsetX, offsetY, r, g, b, a, blur, clip) {
  if (!canvasContext) return;
  canvasContext.save();
  if (clip === 1) {
    canvasContext.beginPath();
    roundedRectPath(canvasContext, x, y, w, h, radius);
    canvasContext.clip();
  }
  canvasContext.shadowColor = colorToString(r, g, b, a);
  canvasContext.shadowBlur = blur;
  canvasContext.shadowOffsetX = offsetX;
  canvasContext.shadowOffsetY = offsetY;
  canvasContext.fillStyle = 'rgba(0,0,0,0.01)';
  canvasContext.fillRect(x, y, w, h);
  canvasContext.restore();
}

/**
 * Draw a simple path icon (op: 0=fill, 1=stroke).
 */
function canvas2dDrawPath(op, x, y, w, h, r, g, b, a) {
  if (!canvasContext) return;
  // Simple path rendering for icons
  var color = colorToString(r, g, b, a);
  if (op === 0) {
    canvasContext.fillStyle = color;
  } else {
    canvasContext.strokeStyle = color;
  }
}

/**
 * Measure text width using Canvas 2D measureText API.
 * Returns the width in pixels.
 */
function canvas2dMeasureTextWidth(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9,
                                   c10, c11, c12, c13, c14, c15, c16, c17, c18, c19,
                                   len, fontSize, fontWeight) {
  if (!canvasContext) return 0;
  var codes = [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9,
               c10, c11, c12, c13, c14, c15, c16, c17, c18, c19];
  var text = '';
  for (var i = 0; i < len && i < codes.length; i++) {
    if (codes[i] > 0) {
      text += String.fromCharCode(codes[i]);
    }
  }
  canvasContext.font = `${fontWeight} ${fontSize}px system-ui, sans-serif`;
  var metrics = canvasContext.measureText(text);
  return metrics.width;
}

/**
 * Convert r,g,b,a (0.0–1.0) to a CSS color string.
 */
function colorToString(r, g, b, a) {
  var ri = Math.round(r * 255);
  var gi = Math.round(g * 255);
  var bi = Math.round(b * 255);
  return `rgba(${ri},${gi},${bi},${a})`;
}

/**
 * Helper to create a rounded rectangle path.
 */
function roundedRectPath(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

/**
 * Handle touch events from the page.
 */
function handleTouchEvent(type, touch) {
  if (!isRunning || !wasmInstance) return;
  var deltaX = 0.0;
  var deltaY = 0.0;
  if (type === 'move') {
    deltaX = touch.x - lastTouchX;
    deltaY = touch.y - lastTouchY;
  }
  lastTouchX = touch.x;
  lastTouchY = touch.y;

  if (type === 'move') {
    if (pendingTouchMove) {
      pendingTouchMove.x = touch.x;
      pendingTouchMove.y = touch.y;
      pendingTouchMove.deltaX += deltaX;
      pendingTouchMove.deltaY += deltaY;
    } else {
      pendingTouchMove = {
        x: touch.x,
        y: touch.y,
        deltaX: deltaX,
        deltaY: deltaY,
      };
    }
    scheduleTouchMove();
    return;
  }

  flushTouchMove();
  dispatchPointerInput(type === 'start' ? 1 : 2, touch.x, touch.y, 0.0, 0.0);
}

function scheduleTouchMove() {
  if (touchFrameScheduled) return;
  touchFrameScheduled = true;
  const requestFrame = canvasNode && canvasNode.requestAnimationFrame
    ? canvasNode.requestAnimationFrame.bind(canvasNode)
    : (callback) => setTimeout(callback, 16);
  requestFrame(() => {
    touchFrameScheduled = false;
    flushTouchMove();
  });
}

function flushTouchMove() {
  if (!pendingTouchMove) return;
  const move = pendingTouchMove;
  pendingTouchMove = null;
  dispatchPointerInput(0, move.x, move.y, move.deltaX, move.deltaY);
}

function dispatchPointerInput(kind, x, y, deltaX, deltaY) {
  if (!isRunning || !wasmInstance) return;
  var exports = wasmInstance.exports;
  if (exports.wechat_dispatch_pointer_input) {
    exports.wechat_dispatch_pointer_input(
      0,
      kind,
      x,
      y,
      deltaX,
      deltaY,
      0,
      0,
    );
  }
}

/**
 * Start the render loop (requestAnimationFrame driven).
 */
function startRenderLoop() {
  if (isRunning) return;
  isRunning = true;
  const requestFrame = canvasNode && canvasNode.requestAnimationFrame
    ? canvasNode.requestAnimationFrame.bind(canvasNode)
    : (callback) => setTimeout(callback, 16);
  const loop = () => {
    if (!isRunning) return;
    if (wasmInstance && wasmInstance.exports.wechat_render_frame) {
      wasmInstance.exports.wechat_render_frame();
    }
    renderFrameId = requestFrame(loop);
  };
  renderFrameId = requestFrame(loop);
}

/**
 * Stop the render loop.
 */
function stopRenderLoop() {
  isRunning = false;
  pendingTouchMove = null;
  if (renderFrameId != null) {
    const cancelFrame = canvasNode && canvasNode.cancelAnimationFrame
      ? canvasNode.cancelAnimationFrame.bind(canvasNode)
      : clearTimeout;
    cancelFrame(renderFrameId);
    renderFrameId = null;
  }
}

/**
 * Get the canvas context.
 */
function getCanvasContext() {
  return canvasContext;
}

module.exports = {
  initMoui: initMoui,
  handleTouchEvent: handleTouchEvent,
  startRenderLoop: startRenderLoop,
  stopRenderLoop: stopRenderLoop,
  getCanvasContext: getCanvasContext,
};
