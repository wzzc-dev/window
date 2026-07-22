///|
/// WeChat Mini Program application state.
pub(all) enum AppState {
  Active
  Inactive
  Background
}

///|
pub fn AppState::is_active(self : AppState) -> Bool {
  match self {
    Active => true
    _ => false
  }
}
