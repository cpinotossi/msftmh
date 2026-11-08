"""Adapt Container Apps managed identity endpoint for the Terraform MSI backend."""

import http.server
import os
import re
import urllib.error
import urllib.request

ENDPOINT = os.environ["IDENTITY_ENDPOINT"]
HEADER = os.environ["IDENTITY_HEADER"]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        query = self.path.partition("?")[2]
        query = re.sub(r"api-version=[^&]+", "api-version=2019-08-01", query)
        request = urllib.request.Request(ENDPOINT + "?" + query, headers={"X-IDENTITY-HEADER": HEADER})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
                self.send_response(200)
        except urllib.error.HTTPError as error:
            body = error.read()
            self.send_response(error.code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", 54321), Handler).serve_forever()
