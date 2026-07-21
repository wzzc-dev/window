@Entry
@Component
struct Index {
  build() {
    Stack() {
      XComponent({
        id: 'window_harmonyos_hosted_surface',
        type: XComponentType.SURFACE,
        libraryname: 'window_harmonyos_hosted'
      })
        .width('100%')
        .height('100%')
    }
      .width('100%')
      .height('100%')
  }
}
