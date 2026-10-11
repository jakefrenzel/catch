"""Print the UDID of an available iPhone simulator on the newest installed iOS runtime."""
import json
import re
import subprocess
import sys

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
        if d.get("isAvailable") and d["name"].startswith("iPhone"):
            if best is None or version > best[0]:
                best = (version, d["udid"], d["name"])

if best is None:
    sys.exit("No available iPhone simulator found")

print(f"Using {best[2]} (iOS {best[0][0]}.{best[0][1]})", file=sys.stderr)
print(best[1])
