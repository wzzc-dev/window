///|
pub impl Show for EventLoopProxy with fn output(self, logger) {
  logger.write_string("EventLoopProxy(")
  logger.write_object(self.wake_fd)
  logger.write_string(")")
}

///|
pub impl Show for EventLoop with fn output(self, logger) {
  logger.write_string("EventLoop(")
  logger.write_object(self.context)
  logger.write_string(")")
}

///|
pub impl Show for EventLoopBuilder with fn output(_self, logger) {
  logger.write_string("EventLoopBuilder(..)")
}

///|
pub impl Show for ActiveEventLoop with fn output(self, logger) {
  logger.write_string("ActiveEventLoop(")
  logger.write_object(self.inner.context)
  logger.write_string(")")
}

///|
pub impl Show for Window with fn output(self, logger) {
  logger.write_string("Window(")
  logger.write_object(self.id)
  logger.write_string(")")
}
