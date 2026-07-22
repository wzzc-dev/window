# window/android package layout

Self-contained hosted backend package (winit-shaped EventLoop + HostCmd).

| Path | Role |
|------|------|
| `*.mbt` | EventLoop, Window, host queue, soft present |
| `native_android_host.*` | C HostCmd queue / platform present hooks |
| `native/` | OS entry / EventLoop bootstrap for installable hosts |
| `template/` | Thin OS app shell (Activity / UIApplication / Ability) |
| `scripts/` | Package-local packaging entry |

Host-sim:

```sh
moon test android --target native
```
