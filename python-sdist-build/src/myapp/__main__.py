import logging
from http.server import BaseHTTPRequestHandler, HTTPServer

import click
from rich.logging import RichHandler
import docopt            # the sdist-built dep

log = logging.getLogger("myapp")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        log.info("GET %s", self.path)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        # call the sdist-built dep so the response proves it imported + ran:
        body = "hello world (%s ok)\n" % docopt.__name__
        self.wfile.write(body.encode())

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
