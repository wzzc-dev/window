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
const windowsLibFlags =
  "-luser32 -lgdi32 -lkernel32 -lole32 -loleaut32 -lshell32 -ldwmapi -limm32 -lshcore";
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
