const fs = require("fs");
const path = require("path");

function readModuleName() {
  const moonModPath = path.join(__dirname, "moon.mod");
  if (fs.existsSync(moonModPath)) {
    const source = fs.readFileSync(moonModPath, "utf8");
    const match = source.match(/^name\s*=\s*"([^"]+)"/m);
    if (match !== null) {
      return match[1];
    }
  }

  const legacyConfigPath = path.join(__dirname, "moon.mod.json");
  const legacyConfig = JSON.parse(fs.readFileSync(legacyConfigPath, "utf8"));
  return legacyConfig.name;
}

const moduleName = readModuleName();
const macosPackageName = `${moduleName}/macos`;
const windowsPackageName = `${moduleName}/windows`;
const linuxPackageName = `${moduleName}/linux`;
const examplesUtilPackageName = `${moduleName}/examples/util`;
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
  "shcore",
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

function fileIsAtLeastAsNewAs(file, dependency) {
  if (!fs.existsSync(file)) {
    return false;
  }
  return fs.statSync(file).mtimeMs >= fs.statSync(dependency).mtimeMs;
}

function ensureGeneratedFile(command, args, output, dependency, description) {
  if (fileIsAtLeastAsNewAs(output, dependency)) {
    return;
  }
  runRequired(command, args, description);
}

function ensureWaylandProtocol(name, xmlParts, headerName, sourceName) {
  const generatedDir = path.join(__dirname, "linux", "generated");
  const header = path.join(generatedDir, headerName);
  const source = path.join(generatedDir, sourceName);
  if (!isLinux) {
    return;
  }
  fs.mkdirSync(generatedDir, { recursive: true });
  const protocolPath =
    commandOutput("pkg-config", [
      "--variable=pkgdatadir",
      "wayland-protocols",
    ]) || "/usr/share/wayland-protocols";
  const protocolXml = path.join(protocolPath, ...xmlParts);
  if (!fs.existsSync(protocolXml)) {
    throw new Error(
      `${name} protocol XML not found at ${protocolXml}; install wayland-protocols`,
    );
  }
  ensureGeneratedFile(
    "wayland-scanner",
    [ "client-header", protocolXml, header ],
    header,
    protocolXml,
    `generate ${name} client header`,
  );
  ensureGeneratedFile(
    "wayland-scanner",
    [ "private-code", protocolXml, source ],
    source,
    protocolXml,
    `generate ${name} client source`,
  );
}

ensureWaylandProtocol(
  "xdg-shell",
  [ "stable", "xdg-shell", "xdg-shell.xml" ],
  "xdg-shell-client-protocol.h",
  "xdg-shell-protocol.c",
);
ensureWaylandProtocol(
  "xdg-decoration",
  [ "unstable", "xdg-decoration", "xdg-decoration-unstable-v1.xml" ],
  "xdg-decoration-client-protocol.h",
  "xdg-decoration-protocol.c",
);

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
