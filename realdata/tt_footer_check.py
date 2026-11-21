"""Week 15: check that every partition of the full tall table on Colibrí opens (parquet footer: rows, row groups, schema).
Reads only footers.   $TALLTABLE_PYTHON -u realdata/tt_footer_check.py → logs the bad ones and a summary."""
import os, time
from pathlib import Path
import pyarrow.parquet as pq
DB = Path(os.environ.get("TALLTABLE_DB_DIR", "/fs1/project/18-interstellar/data/talltable"))
parts = [l.strip() for l in open(DB / "parts.txt") if l.strip()]
dirs = sorted(d.name[5:] for d in (DB / "pixels").iterdir())
print(f"parts.txt {len(parts)}, partition folders {len(dirs)}; in folders not in parts.txt: {sorted(set(dirs) - set(parts))[:10]}; "
      f"in parts.txt without a folder: {sorted(set(parts) - set(dirs))[:10]}", flush=True)
ref = None; bad = 0; rows = 0; t0 = time.time()
for i, p in enumerate(dirs):
    try:
        m = pq.ParquetFile(DB / "pixels" / f"part={p}" / "compacted.parquet")
        s = m.schema_arrow.remove_metadata(); ref = ref or s
        if s != ref: print(f"part={p}: schema differs: {s}", flush=True); bad += 1
        rows += m.metadata.num_rows
    except Exception as e:
        print(f"part={p}: BAD {type(e).__name__}: {e}", flush=True); bad += 1
    if (i + 1) % 5000 == 0: print(f"  {i + 1} checked, {time.time() - t0:.0f} s", flush=True)
print(f"done: {len(dirs)} partitions, {bad} bad, {rows:,} rows in total, {time.time() - t0:.0f} s", flush=True)
