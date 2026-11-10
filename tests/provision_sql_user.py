"""Bootstrap a PDB-local CREATE SESSION-only test user from protected parameters."""

import json
import os
import re
import sys


def provision():
    import oracledb

    password = os.environ["BASE_DB_TEST_PASSWORD"]
    if not re.fullmatch(r"[A-Za-z0-9_#-]{9,30}", password):
        raise ValueError("Invalid limited-user password")
    if password == os.environ["BASE_DB_SYS_PASSWORD"]:
        raise ValueError("Test-user and privileged passwords must differ")
    oracledb.init_oracle_client()
    params = oracledb.ConnectParams(
        host=os.environ["TEST_DB_HOST"], port=int(os.environ["TEST_DB_PORT"]),
        service_name=os.environ["TEST_DB_SERVICE"], tcp_connect_timeout=15,
    )
    with oracledb.connect(user="SYSTEM", password=os.environ["BASE_DB_SYS_PASSWORD"], params=params) as connection:
        connection.call_timeout = 30000
        with connection.cursor() as cursor:
            cursor.execute("SELECT sys_context('USERENV', 'CON_NAME'), 1 FROM dual")
            if cursor.fetchone() != (os.environ["TEST_DB_PDB"].upper(), 1):
                raise ValueError("Refusing to provision a user outside the intended PDB")
            # DDL cannot bind a password. The strict allowlist above excludes quotes.
            cursor.execute(f'CREATE USER WORKSHOP IDENTIFIED BY "{password}"')
            cursor.execute("GRANT CREATE SESSION TO WORKSHOP")
    path = "/etc/oracle-workshop/base-db-test.json"
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump({"username": "WORKSHOP", "password": password}, stream)


if __name__ == "__main__":
    try:
        provision()
    except Exception:
        print("PDB-local test-user provisioning failed; secret details suppressed.", file=sys.stderr)
        sys.exit(1)
