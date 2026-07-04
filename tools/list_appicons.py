#!/usr/bin/env python3
"""Print the names of App Icon assets (AssetType "Icon Image") in a .car.
Usage: list_appicons.py <Assets.car>"""
import sys, json, subprocess
car = sys.argv[1]
raw = subprocess.check_output(["assetutil", "--info", car], stderr=subprocess.DEVNULL).decode("utf-8", "replace")
arr = json.loads(raw[raw.find("["):])
names = {a["Name"] for a in arr if isinstance(a, dict) and a.get("AssetType") == "Icon Image" and a.get("Name")}
print("\n".join(sorted(names)))
