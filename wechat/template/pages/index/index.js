// WeChat Mini Program index page.
// Renders MoUI content through a Canvas element.

const { initMoui, handleTouchEvent, startRenderLoop, stopRenderLoop } = require('../../utils/moui-runtime.js');

Page({
  data: {
    canvasReady: false,
    statusBarHeight: 0,
  },

  onLoad() {
    // Get status bar height to avoid overlap
    const sysInfo = wx.getSystemInfoSync();
    this.setData({ statusBarHeight: sysInfo.statusBarHeight || 0 });
    console.log('[MoUI] Page loaded, statusBarHeight:', sysInfo.statusBarHeight);
  },

  onReady() {
    console.log('[MoUI] Page ready, initializing MoUI...');
    initMoui('moui-canvas').then(() => {
      this.setData({ canvasReady: true });
      startRenderLoop();
      console.log('[MoUI] Runtime ready');
    }).catch((err) => {
      console.error('[MoUI] Init failed:', err);
      wx.showModal({
        title: 'MoUI Error',
        content: 'Init failed: ' + (err.message || String(err)),
        showCancel: false,
      });
    });
  },

  onShow() {
    console.log('[MoUI] Page shown');
    startRenderLoop();
  },

  onHide() {
    console.log('[MoUI] Page hidden');
    stopRenderLoop();
  },

  onUnload() {
    console.log('[MoUI] Page unloaded');
    stopRenderLoop();
  },

  onTouchStart(e) {
    const touch = e.touches[0];
    if (touch) {
      handleTouchEvent('start', touch);
    }
  },

  onTouchMove(e) {
    const touch = e.touches[0];
    if (touch) {
      handleTouchEvent('move', touch);
    }
  },

  onTouchEnd(e) {
    const touch = e.changedTouches[0];
    if (touch) {
      handleTouchEvent('end', touch);
    }
  },
});