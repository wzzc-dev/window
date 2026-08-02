///|
pub impl Show for ActiveEventLoop with fn output(_self, logger) {
  logger.write_string("ActiveEventLoop")
}

///|
pub impl Show for EventLoop with fn output(_self, logger) {
  logger.write_string("EventLoop")
}

///|
pub impl Show for EventLoopBuilder with fn output(_self, logger) {
  logger.write_string("EventLoopBuilder")
}

///|
pub impl Show for EventLoopProxy with fn output(_self, logger) {
  logger.write_string("EventLoopProxy")
}

///|
pub impl Show for Window with fn output(self, logger) {
  logger.write_string("Window(\{self.id()})")
}
