# HarmonyOS Ability glue

Call these from Ability lifecycle / XComponent callbacks:

- `mbw_harmonyos_host_on_start/resume/pause/stop/destroy`
- `mbw_harmonyos_host_on_surface_init(window, component_id, w, h, scale)`
- `mbw_harmonyos_host_on_surface_term/resize`
- `mbw_harmonyos_host_on_pointer_*`

MoonBit drains via `host_drain_native_queue` each EventLoop pump.
