# iOS HostCmd bridge

`MBWHostedAppDelegate.m` is the template's production UIKit host. It links
`../native_ios_host.c` for the HostCmd queue and
`../native/mbw_ios_app_entry.c` for the MoonBit EventLoop thread.

All OS lifecycle, surface, resize, and touch callbacks enqueue HostCmd values.
The MoonBit `EventLoop` drains that queue; the template has no inject or
surface-binding API.
