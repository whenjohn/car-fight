#!/usr/bin/env python3
"""Serve the local Car Fight Web smoke with GDExtension-safe headers."""

import functools
import socketserver
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler


class CarFightHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


class LocalHTTPServer(HTTPServer):
    def server_bind(self):
        # Avoid an unnecessary reverse-DNS lookup on this localhost-only server.
        socketserver.TCPServer.server_bind(self)
        self.server_name = self.server_address[0]
        self.server_port = self.server_address[1]


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
    directory = sys.argv[2] if len(sys.argv) > 2 else "build/web"
    handler = functools.partial(CarFightHandler, directory=directory)
    print(f"Car Fight Web: http://127.0.0.1:{port}/", flush=True)
    LocalHTTPServer(("127.0.0.1", port), handler).serve_forever()


if __name__ == "__main__":
    main()
