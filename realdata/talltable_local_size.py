"""Which tall-table partitions (and how many GB) the offset-map patches need, for a local copy downloaded from the
public file server instead of the web service. Fetches only parts.txt (into $TALLTABLE_DB_DIR) and HEADs each file.

    TALLTABLE_DB_DIR=/fs1/scratch/$USER/talltable ~/envs/talltable/bin/python realdata/talltable_local_size.py LEVEL G [tests]
      → prints, per patch (the level-LEVEL pixel at each level-G centre, [plus the two test patches]), the partitions and
        sizes; writes $TALLTABLE_DB_DIR/needed_parts_L<LEVEL>_grid<G>.txt (one partition number per line)
"""
import os, sys
from pathlib import Path
import healpy as hp
import requests

BASE = "https://sdsc-users.flatironinstitute.org/~chainje/talltable"
DB = Path(os.environ["TALLTABLE_DB_DIR"]); DB.mkdir(parents=True, exist_ok=True)
if not (DB / "parts.txt").exists():
    r = requests.get(f"{BASE}/parts.txt", timeout=120); r.raise_for_status(); (DB / "parts.txt").write_bytes(r.content)
from talltable.partition import find_partitions_ipix, part_to_level_index

level, G = int(sys.argv[1]), int(sys.argv[2])
all_parts = set(int(s) for s in (DB / "parts.txt").read_text().split())
ra_c, dec_c = hp.pix2ang(2 ** G, range(12 * 4 ** G), nest=True, lonlat=True)
specs = [(f"g{G}_{i:03d}", r, d) for i, (r, d) in enumerate(zip(ra_c, dec_c))]
if sys.argv[3:] == ["tests"]:            # the two test patches too (the pole alone is 64 level-9 partitions, ~150 GB)
    specs += [("b30l210", 218.487, 16.649), ("nep", 270.0, 66.560708)]
size, need, total = {}, {}, 0
for name, ra, dec in specs:
    pix = int(hp.ang2pix(2 ** level, ra, dec, nest=True, lonlat=True))
    parts = sorted(int(p) for p in find_partitions_ipix([pix], level, all_parts=all_parts))
    for p in parts:
        if p not in size:
            h = requests.head(f"{BASE}/pixels/part={p}/compacted.parquet", timeout=60)
            size[p] = int(h.headers.get("content-length", 0)) if h.ok else -1
    need[name] = parts
    gb = sum(size[p] for p in parts) / 1e9
    print(f"{name}: ra {ra:7.2f} dec {dec:6.2f}  {len(parts)} part(s) "
          f"{[part_to_level_index(p) for p in parts]}  {gb:.2f} GB", flush=True)
uniq = sorted(size)
print(f"TOTAL: {len(uniq)} distinct partitions, {sum(max(size[p], 0) for p in uniq) / 1e9:.1f} GB; "
      f"missing on server: {[p for p in uniq if size[p] < 0]}")
(DB / f"needed_parts_L{level}_grid{G}.txt").write_text("".join(f"{p}\n" for p in uniq))
