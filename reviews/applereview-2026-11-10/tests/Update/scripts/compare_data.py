#!/usr/bin/env python3
"""Compares two snapshots of Tasquel's data container (Documents/checklist.json and
settings.json, and the app's preferences plist).

  python3 -I compare_data.py <before-dir> <after-dir> [--allow PATH_SUBSTRING ...]

Arrays of objects are matched by "id" (tasks, sub-tasks, categories), "startDay" (weeks) or
"name", so a reordered array isn't a change. It prints:
  CHANGED  path: old -> new     (an old value that's different now)
  MISSING  path                 (an old key or element that's gone)
  ADDED    path                 (an element that wasn't there: duplicated/new items)
  NEWKEY   key (count)          (a field the new version writes; fine)
Exit status 1 if anything CHANGED or MISSING (or ADDED elements) that isn't allowed by --allow.
"""
import json, os, plistlib, sys
from collections import Counter

def load(path):
    with open(path, "rb") as f:
        data = f.read()
    if path.endswith(".plist"):
        return plistlib.loads(data)
    return json.loads(data)

def key_of(item):
    if isinstance(item, dict):
        for k in ("id", "startDay", "name"):
            if k in item:
                return f"{k}={item[k]}"
    return None

def label(item):
    if isinstance(item, dict):
        for k in ("title", "name", "startDay"):
            if k in item:
                return f"[{item[k]}]"
    return ""

problems, newkeys, added = [], Counter(), []

def walk(a, b, path):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in a:
            if k not in b:
                problems.append(f"MISSING  {path}.{k} (was {json.dumps(a[k], default=str)[:80]})")
            else:
                walk(a[k], b[k], f"{path}.{k}")
        for k in b:
            if k not in a:
                newkeys[k] += 1
        return
    if isinstance(a, list) and isinstance(b, list):
        keyed = all(key_of(x) for x in a + b) and (a or b)
        if keyed:
            bk = {key_of(x): x for x in b}
            ak = {key_of(x): x for x in a}
            for k, x in ak.items():
                if k in bk:
                    walk(x, bk[k], f"{path}{label(x)}")
                else:
                    problems.append(f"MISSING  {path}{label(x)} ({k})")
            for k, x in bk.items():
                if k not in ak:
                    added.append(f"ADDED    {path}{label(x)} ({k})")
            # order of keyed elements (tasks in a card, cards in a week) matters to a user
            order_a = [key_of(x) for x in a if key_of(x) in bk]
            order_b = [key_of(x) for x in b if key_of(x) in ak]
            if order_a != order_b:
                problems.append(f"CHANGED  {path} order: {[label(x) for x in a]} -> {[label(x) for x in b]}")
        else:
            if len(a) != len(b) or any(x != y for x, y in zip(a, b)):
                if all(not isinstance(x, (dict, list)) for x in a + b) and sorted(map(str, a)) == sorted(map(str, b)):
                    return
                for i, (x, y) in enumerate(zip(a, b)):
                    walk(x, y, f"{path}[{i}]")
                if len(a) > len(b):
                    problems.append(f"MISSING  {path}[{len(b)}:] {json.dumps(a[len(b):], default=str)[:120]}")
                elif len(b) > len(a):
                    added.append(f"ADDED    {path}[{len(a)}:] {json.dumps(b[len(a):], default=str)[:120]}")
        return
    if a != b:
        problems.append(f"CHANGED  {path}: {json.dumps(a, default=str)[:80]} -> {json.dumps(b, default=str)[:80]}")

def main():
    before, after = sys.argv[1], sys.argv[2]
    allow = sys.argv[sys.argv.index("--allow") + 1:] if "--allow" in sys.argv else []
    files = ["Documents/checklist.json", "Documents/settings.json", "Library/Preferences/com.symonym.Tasquel.plist"]
    for rel in files:
        pa, pb = os.path.join(before, rel), os.path.join(after, rel)
        if not os.path.exists(pa):
            print(f"(no {rel} before)")
            continue
        if not os.path.exists(pb):
            problems.append(f"MISSING  file {rel}")
            continue
        walk(load(pa), load(pb), rel.split("/")[-1])
    bad = 0
    for line in problems + added:
        allowed = any(s in line for s in allow)
        if not allowed:
            bad += 1
        print(("ok(allowed) " if allowed else "") + line)
    for k, n in sorted(newkeys.items()):
        print(f"NEWKEY   {k} ({n})")
    print(f"RESULT   {bad} unexpected difference(s)")
    sys.exit(1 if bad else 0)

main()
