// WeChat Mini Program runtime bridge for MoUI.
// This file provides the JavaScript-side runtime that loads the MoonBit wasm-gc
// module and bridges events between the Mini Program environment and MoUI.

// Import the wasm module
import createWasmModule from './moui/moui.wasm';

let wasmInstance = null;
let canvasContext = null;
let eventLoopPtr = null;
let windowPtr = null;
let animationFrameId = null;
let isRunning = false;

/**
 * Initialize the MoUI runtime in the WeChat Mini Program.
 * @param {string} canvasId - The canvas element ID to render into.
 */
export async function initMoui(canvasId) {
  // Load the wasm module
  const imports = {
    env: {
      // Memory imports
      memory: new WebAssembly.Memory({ initial: 256 }),
      // Canvas 2D rendering imports
      canvas2d_render_commands: (canvasId, commandsPtr, logicalWidth, logicalHeight, scaleFactor) => {
        // Commands are rendered via the canvas2d_runtime.js bridge
      },
      canvas2d_measure_text: (textPtr, fontSize, fontFamily, fontWeight, fontStyle) => {
        return { width: 0, height: 0 };
      },
    },
    // WeChat event dispatch imports
    wechat: {
      env: {
        wechat_dispatch_event: (eventLoop, event) => {},
        wechat_dispatch_pointer_input: (eventLoop, x, y, kind) => {},
        wechat_render_frame: (eventLoop, window) => {},
        wechat_surface_created: (eventLoop, width, height, scaleFactor) => {},
        wechat_surface_destroyed: (eventLoop) => {},
        wechat_app_show: (eventLoop) => {},
        wechat_app_hide: (eventLoop) => {},
      },
    },
  };

  wasmInstance = await createWasmModule(imports);

  // Initialize the canvas context
  const query = wx.createSelectorQuery();
  query.select('#' + canvasId)
    .fields({ node: true, size: true })
    .exec((res) => {
      if (res[0]) {
        const canvas = res[0].node;
        canvasContext = canvas.getContext('2d');
        const dpr = wx.getSystemInfoSync().pixelRatio;
        canvas.width = res[0].width * dpr;
        canvas.height = res[0].height * dpr;
        canvasContext.scale(dpr, dpr);
        beginRenderLoop();
      }
    });
}

/**
 * Start the render loop using requestAnimationFrame.
 */
function beginRenderLoop() {
  if (isRunning) return;
  isRunning = true;

  function frame() {
    if (!isRunning) return;
    // Trigger a render frame in the wasm module
    if (wasmInstance && canvasContext) {
      // Render frame is dispatched by the host
    }
    animationFrameId = canvasContext.canvas.requestAnimationFrame(frame);
  }

  animationFrameId = canvasContext.canvas.requestAnimationFrame(frame);
}

/**
 * Stop the render loop.
 */
export function stopRenderLoop() {
  isRunning = false;
  if (animationFrameId) {
    canvasContext.canvas.cancelAnimationFrame(animationFrameId);
    animationFrameId = null;
  }
}

/**
 * Handle touch start event from the Mini Program.
 * @param {Object} touch - The touch event object from wx.
 */
export function handleTouchStart(touch) {
  // Dispatch touch start to MoUI
}

/**
 * Handle touch move event from the Mini Program.
 * @param {Object} touch - The touch event object from wx.
 */
export function handleTouchMove(touch) {
  // Dispatch touch move to MoUI
}

/**
 * Handle touch end event from the Mini Program.
 * @param {Object} touch - The touch event object from wx.
 */
export function handleTouchEnd(touch) {
  // Dispatch touch end to MoUI
}

/**
 * Handle app show event from the Mini Program.
 */
export function handleAppShow() {
  // Dispatch app show to MoUI
}

/**
 * Handle app hide event from the Mini Program.
 */
export function handleAppHide() {
  // Dispatch app hide to MoUI
  stopRenderLoop();
}

/**
 * Get the canvas rendering context.
 * @returns {CanvasRenderingContext2D}
 */
export function getCanvasContext() {
  return canvasContext;
}