import logging
from http.server import BaseHTTPRequestHandler, HTTPServer

import click
from rich.logging import RichHandler
import nh3            # the sdist-built Rust extension (HTML sanitizer)

log = logging.getLogger("myapp")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        # call into the Rust dep so the response proves the native module built + loaded:
        result = nh3.clean("<b>hello world</b><script>evil()</script>")
        self.wfile.write(("hello world (%s ok)\n" % result).encode())

    def log_message(self, *args):
        pass


@click.command()
@click.option("--addr", default="127.0.0.1:8080")
@click.option("--log-level", default="info")
def main(addr, log_level):
    logging.basicConfig(level=log_level.upper(), format="%(message)s", handlers=[RichHandler()])
    host, _, port = addr.partition(":")
    log.info("serving on %s", addr)
    HTTPServer((host, int(port)), Handler).serve_forever()


if __name__ == "__main__":
    main()
