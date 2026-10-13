"""Print the UDID of an available iPhone simulator on the newest installed iOS runtime.

Pass a device name (e.g. "iPhone 17 Pro Max") to pick that model; otherwise any iPhone.
"""
import json
import re
import subprocess
import sys

wanted = sys.argv[1] if len(sys.argv) > 1 else None

out = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    check=True, capture_output=True, text=True,
).stdout

best = None
for runtime, devices in json.loads(out)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        matches = d["name"] == wanted if wanted else d["name"].startswith("iPhone")
        if d.get("isAvailable") and matches:
            if best is None or version > best[0]:
                best = (version, d["udid"], d["name"])

if best is None:
    sys.exit(f"No available {wanted or 'iPhone'} simulator found")

print(f"Using {best[2]} (iOS {best[0][0]}.{best[0][1]})", file=sys.stderr)
print(best[1])
