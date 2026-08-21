import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { connect as connectTcp } from "node:net";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const CODEX_HOST = "127.0.0.1";
const WEB_HOST = process.env.CODEX_MOBILE_BIND_ADDRESS ?? "127.0.0.1";
const WEB_PORT = 8765;
const CODEX_PORT = 8766;
const LOOPBACK_ORIGIN = `http://127.0.0.1:${WEB_PORT}`;
const PUBLIC_ORIGIN = normalizePublicOrigin(
  process.env.CODEX_MOBILE_PUBLIC_URL ?? LOOPBACK_ORIGIN,
);
const ALLOWED_ORIGINS = new Set([LOOPBACK_ORIGIN, PUBLIC_ORIGIN]);
const here = dirname(fileURLToPath(import.meta.url));
const codexExecutable = process.env.CODEX_EXECUTABLE ?? join(
  process.env.LOCALAPPDATA ?? "",
  "CodexTools",
  "codex.exe",
);

let codexProcess;

function normalizePublicOrigin(value) {
  const url = new URL(value);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("CODEX_MOBILE_PUBLIC_URL must use HTTP or HTTPS.");
  }
  return url.origin;
}

function startCodex() {
  codexProcess = spawn(
    codexExecutable,
    ["app-server", "--listen", `ws://${CODEX_HOST}:${CODEX_PORT}`],
    {
      cwd: dirname(here),
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  codexProcess.stdout.on("data", (chunk) => process.stdout.write(`[codex] ${chunk}`));
  codexProcess.stderr.on("data", (chunk) => process.stderr.write(`[codex] ${chunk}`));
  codexProcess.on("exit", (code, signal) => {
    console.error(`Codex app-server exited (code=${code}, signal=${signal}).`);
  });
}

const server = createServer(async (request, response) => {
  console.log(`[web] ${request.method} ${request.url}`);
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("X-Content-Type-Options", "nosniff");

  if (request.url === "/health") {
    response.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({
      status: "ok",
      codexPort: CODEX_PORT,
      publicUrl: PUBLIC_ORIGIN,
      transport: "tailscale-v1",
    }));
    return;
  }

  if (request.url === "/public_url.json") {
    response.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({
      url: PUBLIC_ORIGIN,
      public_url: PUBLIC_ORIGIN,
      server_url: PUBLIC_ORIGIN,
      preferred_url: PUBLIC_ORIGIN,
    }));
    return;
  }

  if (request.url === "/manifest.json") {
    response.writeHead(200, { "Content-Type": "application/manifest+json; charset=utf-8" });
    response.end(JSON.stringify({
      name: "Codex 私人端",
      short_name: "Codex",
      start_url: "/",
      display: "standalone",
    }));
    return;
  }

  if (request.url !== "/" && request.url !== "/index.html") {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }

  try {
    const html = await readFile(join(here, "index.html"));
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(html);
  } catch (error) {
    response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    response.end(error.message);
  }
});

server.on("upgrade", (request, socket, head) => {
  console.log(`[websocket] ${request.url} origin=${request.headers.origin ?? "none"}`);
  if (request.url !== "/codex" || !ALLOWED_ORIGINS.has(request.headers.origin)) {
    console.warn("[websocket] rejected request");
    socket.end("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n");
    return;
  }

  const upstream = connectTcp({ host: CODEX_HOST, port: CODEX_PORT });
  const closeBoth = () => {
    socket.destroy();
    upstream.destroy();
  };

  socket.on("error", closeBoth);
  upstream.on("error", () => {
    if (!socket.destroyed) {
      socket.end("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n");
    }
    upstream.destroy();
  });

  upstream.on("connect", () => {
    console.log("[websocket] connected to Codex app-server");
    const forwardedHeaders = Object.entries(request.headers)
      .filter(([name]) => name !== "host" && name !== "origin")
      .flatMap(([name, value]) => {
        const values = Array.isArray(value) ? value : [value];
        return values.filter(Boolean).map((item) => `${name}: ${item}`);
      });
    const handshake = [
      "GET / HTTP/1.1",
      `Host: ${CODEX_HOST}:${CODEX_PORT}`,
      ...forwardedHeaders,
      "",
      "",
    ].join("\r\n");

    upstream.write(handshake);
    if (head.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
});

function shutdown() {
  server.close();
  codexProcess?.kill();
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
process.on("exit", () => codexProcess?.kill());

startCodex();
server.listen(WEB_PORT, WEB_HOST, () => {
  console.log(`Codex private mobile host: http://${WEB_HOST}:${WEB_PORT}`);
  console.log(`Codex private mobile public URL: ${PUBLIC_ORIGIN}`);
  console.log(`Codex app-server: ws://${CODEX_HOST}:${CODEX_PORT}`);
});
