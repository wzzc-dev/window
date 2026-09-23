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

///|
pub extend ActiveEventLoop with Show::{to_string, output}

///|
pub extend EventLoop with Show::{to_string, output}

///|
pub extend EventLoopBuilder with Show::{to_string, output}

///|
pub extend EventLoopProxy with Show::{to_string, output}

///|
pub extend Window with Show::{to_string, output}
