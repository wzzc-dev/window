# window/android package layout

Self-contained hosted backend package (winit-shaped EventLoop + HostCmd).

| Path | Role |
|------|------|
| `*.mbt` | EventLoop, Window, host queue, soft present |
| `native_android_host.*` | C HostCmd queue / platform present hooks |
| `native/` | OS entry / EventLoop bootstrap for installable hosts |
| `template/` | Thin OS app shell (Activity / UIApplication / Ability) |
| `scripts/` | Package-local packaging entry |

MoUI monorepo wrappers:

- `scripts/build-window-hosted-*.sh` → `window/android/scripts/*`

Host-sim:

```sh
bash window/scripts/check_android_hosted_smoke.sh
```
