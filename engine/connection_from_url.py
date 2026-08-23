#!/usr/bin/env python3
"""Convert a postgres:// URL into a Wren connection document (JSON).

The Wren engine takes connections as structured fields (host, port,
database, user, password, kwargs); Adilade configures the warehouse with a
single WAREHOUSE_DATABASE_URL env var. This bridges the two.

Usage:
    connection_from_url.py <postgres-url>            # for --connection-file
    connection_from_url.py <postgres-url> --profile  # for `wren profile add --from-file`

Output is always JSON (`wren profile add` parses unknown file suffixes as
JSON, so this works with mktemp files). The two modes differ in one way:
profile values pass through the engine's ${VAR} secret expansion at serve
time, so --profile escapes literal `$` as `$$` to round-trip; the
--connection-file path bypasses expansion and gets values verbatim.

Query parameters (e.g. ?sslmode=require&connect_timeout=10) are forwarded
under "kwargs", which the engine's postgres connector passes straight to
psycopg/libpq — so TLS requirements in the URL are honored, not dropped.

Stdlib only — must run in a bare python:slim image before any pip installs.
"""
import json
import sys
from urllib.parse import parse_qsl, unquote, urlparse


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__, file=sys.stderr)
        return 2
    url, for_profile = args[0], "--profile" in args[1:]

    u = urlparse(url)
    if u.scheme not in ("postgres", "postgresql"):
        print(f"error: expected a postgres:// URL, got scheme {u.scheme!r}", file=sys.stderr)
        return 1
    try:
        port = u.port or 5432
    except ValueError:
        print("error: invalid port in URL", file=sys.stderr)
        return 1
    database = (u.path or "").lstrip("/")
    if not u.hostname or not database:
        print("error: URL must include a host and a database name", file=sys.stderr)
        return 1

    conn = {
        "datasource": "postgres",
        "host": u.hostname,
        "port": port,
        "database": unquote(database),
        "user": unquote(u.username or ""),
        "password": unquote(u.password or ""),
    }
    kwargs = dict(parse_qsl(u.query)) if u.query else {}
    if kwargs:
        conn["kwargs"] = kwargs

    if for_profile:
        conn = {
            k: (v.replace("$", "$$") if isinstance(v, str) else v)
            for k, v in conn.items()
            if k != "kwargs"
        }
        if kwargs:
            conn["kwargs"] = {k.replace("$", "$$"): v.replace("$", "$$") for k, v in kwargs.items()}

    print(json.dumps(conn))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
