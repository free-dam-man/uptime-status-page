#!/usr/bin/env python3
import asyncio, os, sys

PUBLIC = int(os.environ.get("PORT", "8080"))
BACKEND = 8081
ROUTE = os.environ.get("ROUTE_PATH") or os.environ.get("WSPATH") or "/api/events"
if not ROUTE.startswith("/"):
    ROUTE = "/" + ROUTE

HTML = b"""<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content=\"width=device-width,initial-scale=1\">
<title>Uptime Status</title>
<style>
body{font-family:system-ui,sans-serif;margin:0;background:#0b1220;color:#e8eefc}
main{max-width:640px;margin:12vh auto;padding:2rem}
.card{background:#121a2b;border:1px solid #243049;border-radius:12px;padding:1.5rem}
h1{font-size:1.25rem;margin:0 0 .5rem}p{opacity:.8;margin:0}
.ok{display:inline-block;margin-top:1rem;padding:.35rem .7rem;border-radius:999px;background:#123528;color:#6dffb0;font-size:.85rem}
</style></head><body><main><div class=card>
<h1>Service status</h1>
<p>All monitored endpoints are reachable.</p>
<span class=ok>Operational</span>
</div></main></body></html>"""

async def pipe(a, b):
    try:
        while True:
            data = await a.read(65536)
            if not data:
                break
            b.write(data)
            await b.drain()
    except Exception:
        pass
    try:
        b.close()
    except Exception:
        pass

async def handle(reader, writer):
    try:
        req = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=30)
    except Exception:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass
        return
    head = req.split(b"\r\n", 1)[0].decode("latin1", "replace")
    parts = head.split(" ")
    target = parts[1] if len(parts) > 1 else "/"
    path = target.split("?", 1)[0]
    if path == ROUTE or path.startswith(ROUTE + "/"):
        try:
            br, bw = await asyncio.open_connection("127.0.0.1", BACKEND)
        except Exception:
            writer.write(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            await writer.drain()
            writer.close()
            return
        bw.write(req)
        await bw.drain()
        await asyncio.gather(pipe(reader, bw), pipe(br, writer))
        return
    if path in ("/healthz", "/health", "/ready"):
        body = b"ok\n"
        ctype = b"text/plain"
    else:
        body = HTML
        ctype = b"text/html; charset=utf-8"
    writer.write(
        b"HTTP/1.1 200 OK\r\nContent-Type: " + ctype + b"\r\nContent-Length: "
        + str(len(body)).encode()
        + b"\r\nConnection: close\r\n\r\n"
        + body
    )
    await writer.drain()
    writer.close()
    try:
        await writer.wait_closed()
    except Exception:
        pass

async def main():
    server = await asyncio.start_server(handle, "0.0.0.0", PUBLIC)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
