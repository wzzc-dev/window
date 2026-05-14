import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const here = fileURLToPath(new URL(".", import.meta.url));
const root = resolve(here, "../..");
const port = Number(process.env.PORT || 8000);
const host = process.env.HOST || "127.0.0.1";

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".wasm", "application/wasm"],
]);

function safePath(url) {
  const pathname = decodeURIComponent(new URL(url, `http://${host}:${port}`).pathname);
  const relative = normalize(pathname).replace(/^([/\\])+/, "");
  const full = resolve(join(root, relative));
  if (full !== root && !full.startsWith(root + sep)) {
    return undefined;
  }
  return full;
}

const server = createServer(async (request, response) => {
  const full = safePath(request.url || "/");
  if (!full) {
    response.writeHead(403).end("Forbidden");
    return;
  }

  let file = full;
  try {
    const info = await stat(file);
    if (info.isDirectory()) {
      file = join(file, "index.html");
    }
    const contentType = mimeTypes.get(extname(file)) || "application/octet-stream";
    response.writeHead(200, {
      "cache-control": "no-store",
      "content-type": contentType,
    });
    if (request.method !== "HEAD") {
      createReadStream(file).pipe(response);
    } else {
      response.end();
    }
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Not found");
  }
});

server.listen(port, host, () => {
  console.log(`Serving ${root} at http://${host}:${port}/`);
  console.log(`Open http://${host}:${port}/examples/window_web/index.html`);
});
