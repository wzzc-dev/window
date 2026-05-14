///|
pub impl Show for EventLoop with output(_self, logger) {
  logger.write_string("EventLoop(web)")
}

///|
pub impl Show for ActiveEventLoop with output(_self, logger) {
  logger.write_string("ActiveEventLoop(web)")
}

///|
pub impl Show for EventLoopProxy with output(_self, logger) {
  logger.write_string("EventLoopProxy(web)")
}

///|
pub impl Show for EventLoopBuilder with output(_self, logger) {
  logger.write_string("EventLoopBuilder(web)")
}

///|
pub impl Show for Window with output(self, logger) {
  logger.write_string("Window(id=")
  logger.write_string(self.id().into_raw().to_string())
  logger.write_string(", canvas_id=")
  logger.write_string(self.canvas_id())
  logger.write_string(")")
}
