///|
pub(all) enum PollStrategy {
  AnimationFrame
  Timeout(Int)
}

///|
pub struct WindowAttributesWeb {
  priv mut canvas_id_ : String?
  priv mut append_to_body_ : Bool
} derive(Eq, Debug)

///|
pub fn WindowAttributesWeb::default() -> WindowAttributesWeb {
  { canvas_id_: None, append_to_body_: true }
}

///|
pub fn WindowAttributesWeb::with_canvas_id(
  self : WindowAttributesWeb,
  canvas_id : String,
) -> WindowAttributesWeb {
  self.canvas_id_ = Some(canvas_id)
  self
}

///|
pub fn WindowAttributesWeb::canvas_id(self : WindowAttributesWeb) -> String? {
  self.canvas_id_
}

///|
pub fn WindowAttributesWeb::with_append_to_body(
  self : WindowAttributesWeb,
  append_to_body : Bool,
) -> WindowAttributesWeb {
  self.append_to_body_ = append_to_body
  self
}

///|
pub fn WindowAttributesWeb::append_to_body(self : WindowAttributesWeb) -> Bool {
  self.append_to_body_
}

///|
pub fn EventLoop::set_poll_strategy(
  self : EventLoop,
  strategy : PollStrategy,
) -> Unit {
  let _ = self
  app_state_set_poll_strategy(strategy)
}

///|
pub fn EventLoop::poll_strategy(self : EventLoop) -> PollStrategy {
  let _ = self
  app_state_poll_strategy()
}

///|
pub fn ActiveEventLoop::set_poll_strategy(
  self : ActiveEventLoop,
  strategy : PollStrategy,
) -> Unit {
  let _ = self
  app_state_set_poll_strategy(strategy)
}

///|
pub fn ActiveEventLoop::poll_strategy(self : ActiveEventLoop) -> PollStrategy {
  let _ = self
  app_state_poll_strategy()
}
