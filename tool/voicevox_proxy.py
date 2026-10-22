#!/usr/bin/env python3
"""Proxy HTTP: forward LAN port 50021 -> 127.0.0.1:50021 (VOICEVOX).

Sebab: VOICEVOX engine mendengarkan hanya di loopback, sehingga HP fisik di
LAN tidak bisa menjangkau. Script ini listen di semua interface (atau IP LAN)
dan meneruskan method + query + body apa adanya ke loopback.

Jalankan:
    python3 tool/voicevox_proxy.py [host] [port]
Contoh host default: 0.0.0.0 (semua interface).
"""

import http.server
import socketserver
import sys
import urllib.error
import urllib.request

UPSTREAM = "127.0.0.1:50021"
DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 50021


def _pick_lan_ip() -> str:
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return "0.0.0.0"
    finally:
        s.close()


class _Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def _forward(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() not in ("host", "connection")
        }
        req = urllib.request.Request(
            f"http://{UPSTREAM}{self.path}",
            data=body,
            headers=headers,
            method=self.command,
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self._send_header(resp.headers.get("Content-Type"), data)
        except urllib.error.HTTPError as err:
            data = err.read()
            self.send_response(err.code)
            self._send_header(
                err.headers.get("Content-Type", "application/json"), data
            )
        except Exception:
            self.send_response(502)
            self._send_header("application/json", b'{"detail":"proxy error"}')

    def _send_header(self, content_type, data: bytes) -> None:
        self.send_header("Content-Type", content_type or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = _forward
    do_POST = _forward
    do_PUT = _forward
    do_DELETE = _forward

    def log_message(self, *args) -> None:  # satukan output
        pass


def main() -> None:
    host = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_HOST
    port = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_PORT

    if host == "0.0.0.0":
        try:
            server = socketserver.ThreadingTCPServer((host, port), _Handler)
        except OSError:
            host = _pick_lan_ip()
            server = socketserver.ThreadingTCPServer((host, port), _Handler)
    else:
        server = socketserver.ThreadingTCPServer((host, port), _Handler)

    server.allow_reuse_address = True
    print(f"voicevox-proxy {host}:{port} -> {UPSTREAM} (Ctrl+C untuk berhenti)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()


if __name__ == "__main__":
    main()