#!/usr/bin/env python3
"""Convert a postgres:// URL into a Wren connection document.

The Wren engine takes connections as structured fields (host, port,
database, user, password); Adilade configures the warehouse with a single
WAREHOUSE_DATABASE_URL env var. This bridges the two.

Usage:
    connection_from_url.py <postgres-url>          # JSON (for --connection-file)
    connection_from_url.py <postgres-url> --yaml   # YAML (for `wren profile add --from-file`)

Stdlib only — must run in a bare python:slim image before any pip installs.
"""
import json
import sys
from urllib.parse import unquote, urlparse


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__, file=sys.stderr)
        return 2
    url, as_yaml = args[0], "--yaml" in args[1:]

    u = urlparse(url)
    if u.scheme not in ("postgres", "postgresql"):
        print(f"error: expected a postgres:// URL, got scheme {u.scheme!r}", file=sys.stderr)
        return 1
    database = (u.path or "").lstrip("/")
    if not u.hostname or not database:
        print("error: URL must include a host and a database name", file=sys.stderr)
        return 1

    conn = {
        "datasource": "postgres",
        "host": u.hostname,
        "port": u.port or 5432,
        "database": unquote(database),
        "user": unquote(u.username or ""),
        "password": unquote(u.password or ""),
    }
    if as_yaml:
        # JSON scalar encoding is valid YAML, so json.dumps handles quoting.
        print("\n".join(f"{k}: {json.dumps(v)}" for k, v in conn.items()))
    else:
        print(json.dumps(conn))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
