export const startEventLoop: () => boolean;
export const hostOnStart: () => void;
export const hostOnResume: () => void;
export const hostOnPause: () => void;
export const hostOnStop: () => void;
export const hostOnDestroy: () => void;
export const hostOnMemoryWarning: () => void;
export const requestClipboardRead: () => boolean;
export const setClipboardAffordanceListener: (callback: (visible: boolean) => void) => boolean;
