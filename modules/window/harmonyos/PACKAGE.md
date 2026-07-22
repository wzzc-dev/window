# window/harmonyos package layout

Self-contained hosted backend package (winit-shaped EventLoop + HostCmd).

| Path | Role |
|------|------|
| `*.mbt` | EventLoop, Window, host queue, soft present |
| `native_harmonyos_host.*` | C HostCmd queue / platform present hooks |
| `native/` | OS entry / EventLoop bootstrap for installable hosts |
| `template/` | Thin OS app shell (Activity / UIApplication / Ability) |
| `scripts/` | Package-local packaging entry |

Host-sim:

```sh
moon test harmonyos --target native
```
