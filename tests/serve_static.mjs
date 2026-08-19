import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { dirname, extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const port = Number.parseInt(process.argv[2] ?? "8765", 10);

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
]);

createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    const relative = decodeURIComponent(url.pathname).replace(/^\/+/, "") || "drone_checker.html";
    const target = resolve(root, relative);
    if (target !== root && !target.startsWith(root + sep)) {
      response.writeHead(403).end("Forbidden");
      return;
    }
    const info = await stat(target);
    if (!info.isFile()) throw new Error("Not a file");
    response.writeHead(200, {
      "Content-Type": contentTypes.get(extname(target)) ?? "application/octet-stream",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    });
    createReadStream(target).pipe(response);
  } catch {
    response.writeHead(404).end("Not Found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`Drone preview: http://127.0.0.1:${port}/drone_checker.html`);
});
