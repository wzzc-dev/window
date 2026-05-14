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

console.log(
  JSON.stringify({
    link_configs: linkConfigs,
  }),
);
