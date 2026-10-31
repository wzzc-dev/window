import windowHosted from 'libwindow_harmonyos_hosted.so';

@Entry
@Component
struct Index {
  // The paste control is hidden by default. Reading the system pasteboard from a
  // normal-level HAP requires a user gesture through the paste security control
  // (ohos.permission.READ_PASTEBOARD is system_basic + user_grant, so a direct
  // OH_Pasteboard_GetData returns ERR_PERMISSION_ERROR 201), but a permanently
  // visible overlay would sit on top of the hosted surface. It appears only while
  // a hosted text field has keyboard focus.
  @State showPaste: boolean = false;

  aboutToAppear(): void {
    // Native side tells us when the hosted text field gains/loses focus.
    windowHosted.setClipboardAffordanceListener((visible: boolean) => {
      this.showPaste = visible;
    });
  }

  build() {
    Stack() {
      XComponent({
        id: 'window_harmonyos_hosted_surface',
        type: XComponentType.SURFACE,
        libraryname: 'window_harmonyos_hosted'
      })
        .width('100%')
        .height('100%')
        // Keyboard input requires the surface to be focusable: the platform
        // only dispatches key events to a focused XComponent. Without this the
        // native key callback never fires and text fields stay empty.
        .focusable(true)
        .defaultFocus(true)
        .focusOnTouch(true)

      if (this.showPaste) {
        Row() {
          PasteButton({ icon: PasteIconStyle.LINES, text: PasteDescription.PASTE })
            .fontSize(12)
            .height(28)
            .onClick((event: ClickEvent, result: PasteButtonOnClickResult) => {
              if (result !== PasteButtonOnClickResult.SUCCESS) {
                return;
              }
              // The native side reads the pasteboard inside the granted window
              // and forwards the text to the hosted surface.
              windowHosted.requestClipboardRead();
              this.showPaste = false;
            })
        }
        .position({ x: 'calc(100% - 96vp)', y: 8 })
      }
    }
      .width('100%')
      .height('100%')
  }
}
