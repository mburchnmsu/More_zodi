"""One trivial query (SELECT 1) to the tall-table web service: exit 0 if it answers, 1 if not (prints the error).
Used by pipeline/cluster/talltable_wait.sbatch to wait for the service to come back without loading it."""
import sys
from talltable import PixelQuery
from talltable.client import fetch_arrow_stream

try:
    fetch_arrow_stream(PixelQuery(web=True)._base_url + "/sql", {"query": "SELECT 1 AS ok", "partitions": []})
    print("tall table: up", flush=True)
except Exception as e:
    print("tall table: down:", str(e).splitlines()[0][:200], flush=True)
    sys.exit(1)
