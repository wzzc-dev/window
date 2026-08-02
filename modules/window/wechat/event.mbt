///|
/// WeChat Mini Program event types.
/// Touch events are the primary input mechanism in Mini Programs.

///|
pub(all) struct WechatTouch {
  x : Double
  y : Double
  identifier : Int
}

///|
pub(all) enum WechatEvent {
  TouchStart(WechatTouch)
  TouchMove(WechatTouch)
  TouchEnd(WechatTouch)
  TouchCancel
  AppShow
  AppHide
  SurfaceCreated(Double, Double, Double)
  SurfaceDestroyed
}

///|
pub fn WechatEvent::is_touch(self : WechatEvent) -> Bool {
  match self {
    TouchStart(_) | TouchMove(_) | TouchEnd(_) | TouchCancel => true
    _ => false
  }
}
