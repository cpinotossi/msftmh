"""SQL proof using a short-lived root-only credential file from protected parameters."""

import ipaddress
import json
import os
from pathlib import Path
import socket
import stat
import statistics
import sys
import time


def resolve():
    actual = {item[4][0] for item in socket.getaddrinfo(os.environ["TEST_DB_HOST"], None)}
    if str(ipaddress.ip_address(os.environ["TEST_DB_IP"])) not in actual:
        raise ValueError("Unexpected DNS result")


def measure_latency(cursor):
    samples = []
    for index in range(11):
        started = time.perf_counter()
        cursor.execute("SELECT 1 FROM dual")
        if cursor.fetchone() != (1,):
            raise ValueError("Unexpected SQL value during latency measurement")
        elapsed = (time.perf_counter() - started) * 1000
        if index:
            samples.append(elapsed)
    return {
        "samples": len(samples), "unit": "ms",
        "min": min(samples), "median": statistics.median(samples), "max": max(samples),
    }


def probe(measure=False):
    import oracledb

    path = Path("/etc/oracle-workshop/base-db-test.json")
    # O_NOFOLLOW prevents a symlink substitution between inspection and opening.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd) as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError("SQL credentials must be a root-owned regular file with mode 0600")
        credentials = json.load(stream)
    for key in ("username", "password"):
        if not isinstance(credentials.get(key), str) or not credentials[key]:
            raise ValueError("Missing SQL credentials")
    # Host/service are authoritative discovery outputs, not supplied by the secret.
    oracledb.init_oracle_client()
    params = oracledb.ConnectParams(
        host=os.environ["TEST_DB_HOST"],
        port=int(os.environ["TEST_DB_PORT"]),
        service_name=os.environ["TEST_DB_SERVICE"],
        tcp_connect_timeout=15,
    )
    with oracledb.connect(user=credentials["username"], password=credentials["password"], params=params) as connection:
        connection.call_timeout = 30000
        with connection.cursor() as cursor:
            cursor.execute("SELECT sys_context('USERENV', 'CON_NAME'), 1 FROM dual")
            row = cursor.fetchone()
            if row != (os.environ["TEST_DB_PDB"].upper(), 1):
                raise ValueError("SQL connected to the wrong container or returned an unexpected value")
            if measure:
                return measure_latency(cursor)


if __name__ == "__main__":
    try:
        resolve()
        if sys.argv[1:] == ["--resolve"]:
            print("DNS_OK")
        elif not sys.argv[1:]:
            probe()
            print("SQL_PDB_OK")
        elif sys.argv[1:] == ["--latency"]:
            print(json.dumps(probe(measure=True), indent=2))
        else:
            raise ValueError("Unexpected arguments")
    except Exception:
        # Driver exceptions can contain connect descriptors; never echo secret-file data.
        print("Base DB SQL/DNS validation failed; check secure provisioning and connectivity.", file=sys.stderr)
        sys.exit(1)
