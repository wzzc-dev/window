const fs = require("fs");
const path = require("path");

const moduleConfigPath = path.join(__dirname, "moon.mod.json");
const moduleConfig = JSON.parse(fs.readFileSync(moduleConfigPath, "utf8"));
const macosPackageName = `${moduleConfig.name}/macos`;
const windowsPackageName = `${moduleConfig.name}/windows`;
const linuxPackageName = `${moduleConfig.name}/linux`;
const examplesUtilPackageName = `${moduleConfig.name}/examples/util`;
const macosFrameworkFlags =
  "-framework AppKit -framework Foundation -framework CoreGraphics -framework CoreVideo -framework ApplicationServices -lobjc";
const windowsLibs = [
  "user32",
  "gdi32",
  "kernel32",
  "ole32",
  "oleaut32",
  "shell32",
  "dwmapi",
  "imm32",
  "advapi32",
];

const windowsUsesMsvc =
  Boolean(process.env.VSCMD_VER || process.env.VCINSTALLDIR) ||
  (process.env.CC || "").toLowerCase().endsWith("cl.exe") ||
  (process.env.CC || "").toLowerCase() === "cl";

const windowsLibFlags = windowsUsesMsvc
  ? windowsLibs.map((lib) => `${lib}.lib`).join(" ")
  : windowsLibs.map((lib) => `-l${lib}`).join(" ");

const isWindows = process.platform === "win32";
const isLinux = process.platform === "linux";

function commandOutput(command, args) {
  const { spawnSync } = require("child_process");
  const result = spawnSync(command, args, { encoding: "utf8" });
  if (result.status !== 0) {
    return "";
  }
  return result.stdout.trim();
}

function runRequired(command, args, description) {
  const { spawnSync } = require("child_process");
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(
      `failed to ${description}; install Wayland development dependencies and ensure '${command}' is on PATH`,
    );
  }
}

function ensureXdgShellProtocol() {
  const generatedDir = path.join(__dirname, "linux", "generated");
  const header = path.join(generatedDir, "xdg-shell-client-protocol.h");
  const source = path.join(generatedDir, "xdg-shell-protocol.c");
  if (!isLinux) {
    return;
  }
  fs.mkdirSync(generatedDir, { recursive: true });
  const protocolPath =
    commandOutput("pkg-config", [
      "--variable=pkgdatadir",
      "wayland-protocols",
    ]) || "/usr/share/wayland-protocols";
  const xdgShellXml = path.join(
    protocolPath,
    "stable",
    "xdg-shell",
    "xdg-shell.xml",
  );
  if (!fs.existsSync(xdgShellXml)) {
    throw new Error(
      `xdg-shell protocol XML not found at ${xdgShellXml}; install wayland-protocols`,
    );
  }
  runRequired(
    "wayland-scanner",
    [ "client-header", xdgShellXml, header ],
    "generate xdg-shell client header",
  );
  runRequired(
    "wayland-scanner",
    [ "private-code", xdgShellXml, source ],
    "generate xdg-shell client source",
  );
}

ensureXdgShellProtocol();

const linkConfigs = [
  {
    package: macosPackageName,
    link_flags: macosFrameworkFlags,
  },
  {
    package: examplesUtilPackageName,
    link_flags: macosFrameworkFlags,
  },
];

if (isWindows) {
  linkConfigs.push({
    package: windowsPackageName,
    link_flags: windowsLibFlags,
  });
}

if (isLinux) {
  const waylandFlags =
    commandOutput("pkg-config", [ "--libs", "wayland-client" ]) ||
    "-lwayland-client";
  linkConfigs.push({
    package: linuxPackageName,
    link_flags: waylandFlags,
  });
}

console.log(
  JSON.stringify({
    link_configs: linkConfigs,
  }),
);
