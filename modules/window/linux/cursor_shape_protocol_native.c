#ifdef __linux__
#include "generated/cursor-shape-protocol.c"

// The cursor-shape protocol references the tablet-tool interface in its type
// table, but MoUI never requests get_tablet_tool_v2. Provide the symbol so
// the generated interface table links without pulling in the tablet protocol.
const struct wl_interface zwp_tablet_tool_v2_interface = {
    .name = "zwp_tablet_tool_v2",
    .version = 2,
    .method_count = 0,
    .methods = NULL,
    .event_count = 0,
    .events = NULL,
};
#else
typedef int mbw_wayland_cursor_shape_protocol_stub;
#endif
