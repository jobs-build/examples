import logging
from http.server import BaseHTTPRequestHandler, HTTPServer

import click
from rich.logging import RichHandler

from myapp._native import greeting

log = logging.getLogger("myapp")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        log.info("GET %s", self.path)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((greeting("world") + "\n").encode())  # greeting() is the Rust fn

    def log_message(self, *args):
        pass


@click.command()
@click.option("--addr", default="127.0.0.1:8080", help="listen address host:port")
@click.option("--log-level", default="info", help="logging level (debug/info/warning/error)")
def main(addr, log_level):
    logging.basicConfig(level=log_level.upper(), format="%(message)s", handlers=[RichHandler()])
    host, _, port = addr.partition(":")
    log.info("serving on %s", addr)
    HTTPServer((host, int(port)), Handler).serve_forever()


if __name__ == "__main__":
    main()
