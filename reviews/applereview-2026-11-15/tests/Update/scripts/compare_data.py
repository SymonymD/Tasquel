"""Compare a 1.0.3 data snapshot ("before") with the same data after 1.1 ran ("after").

  python3 -I compare_data.py <before dir> <after dir> [--loose]

Each dir holds checklist.json and settings.json (directly, or under Documents/), and
optionally defaults.plist or Library/Preferences/com.symonym.Tasquel.plist.
Every value 1.0.3 saved must be unchanged in 1.1 (strict: matched by id). New keys are
listed with any non-default value. --loose matches weeks by startDay and tasks by
(card name, title, position) and ignores ids, for comparing two different runs (rollover).
Exit status 1 when an old value changed or went missing.
"""
import json, os, plistlib, sys

NEW_TASK_DEFAULTS = {"hasOwnTitle": False, "isPinned": False, "expiresOn": None, "expirySetOn": None,
                     "expiresWithWeek": False, "dayOfWeek": None, "daySetOn": None}
problems, notes = [], []


def find(base, *names):
    for n in names:
        p = os.path.join(base, n)
        if os.path.exists(p):
            return p
    return None


def load(base):
    cl = find(base, "checklist.json", "Documents/checklist.json")
    st = find(base, "settings.json", "Documents/settings.json")
    pl = find(base, "defaults.plist", "Library/Preferences/com.symonym.Tasquel.plist")
    weeks = json.load(open(cl)) if cl else None
    settings = json.load(open(st)) if st else None
    prefs = plistlib.load(open(pl, "rb")) if pl else {}
    return weeks, settings, prefs


def strip_ids(v):
    if isinstance(v, dict):
        return {k: (bool(x) if k in ("id", "carriedFrom", "repeatsFrom") else strip_ids(x)) for k, x in v.items()}
    if isinstance(v, list):
        return [strip_ids(x) for x in v]
    return v


def compare_dict(path, old, new, loose):
    for k, ov in old.items():
        if k not in new:
            problems.append(f"{path}.{k}: missing in 1.1 (was {json.dumps(ov)[:80]})")
            continue
        nv = new[k]
        if k in ("categories", "tasks", "subtasks"):
            compare_list(f"{path}.{k}", ov, nv, loose)
        elif loose and k in ("id", "carriedFrom", "repeatsFrom", "dismissedCarryOvers"):
            if bool(ov) != bool(nv):
                problems.append(f"{path}.{k}: {'set' if ov else 'unset'} -> {'set' if nv else 'unset'}")
        elif (strip_ids(ov) if loose else ov) != (strip_ids(nv) if loose else nv):
            problems.append(f"{path}.{k}: {json.dumps(ov)[:80]} -> {json.dumps(nv)[:80]}")
    for k in new.keys() - old.keys():
        if k in NEW_TASK_DEFAULTS and new[k] == NEW_TASK_DEFAULTS[k]:
            continue
        if k == "isPinned" and new[k] is False:
            continue
        notes.append(f"{path}.{k}: new key = {json.dumps(new[k])[:80]}")


def label(item):
    return item.get("name") or item.get("title") or "?"


def compare_list(path, old, new, loose):
    if loose:
        if [label(x) for x in old] != [label(x) for x in new]:
            problems.append(f"{path}: {[label(x) for x in old]} -> {[label(x) for x in new]}")
        for i, (o, n) in enumerate(zip(old, new)):
            compare_dict(f"{path}[{label(o)}]", o, n, loose)
        return
    by_id = {x.get("id"): x for x in new}
    for o in old:
        n = by_id.get(o.get("id"))
        if n is None:
            problems.append(f"{path}: '{label(o)}' lost")
            continue
        compare_dict(f"{path}[{label(o)}]", o, n, loose)
    old_ids = {x.get("id") for x in old}
    for n in new:
        if n.get("id") not in old_ids:
            problems.append(f"{path}: '{label(n)}' added")
    if [x.get("id") for x in old] != [x.get("id") for x in new if x.get("id") in old_ids]:
        problems.append(f"{path}: order {[label(x) for x in old]} -> {[label(x) for x in new]}")


def main():
    before, after = sys.argv[1], sys.argv[2]
    loose = "--loose" in sys.argv
    ow, os_, op = load(before)
    nw, ns, np_ = load(after)
    ob = {w["startDay"]: w for w in ow}
    nb = {w["startDay"]: w for w in nw}
    for day, w in ob.items():
        if day not in nb:
            problems.append(f"week {day}: lost")
            continue
        compare_dict(f"week {day}", w, nb[day], loose)
    for day in nb.keys() - ob.keys():
        notes.append(f"week {day}: new in 1.1 ({len(nb[day]['categories'])} cards)")
    if os_ is not None:
        compare_dict("settings", os_, ns or {}, loose)
    for k, v in op.items():
        if k not in np_:
            problems.append(f"defaults.{k}: missing in 1.1")
        elif np_[k] != v and k != "categoryEditTimes":
            problems.append(f"defaults.{k}: {v} -> {np_[k]}")
    for k in np_.keys() - op.keys():
        notes.append(f"defaults.{k}: new = {np_[k]}")
    for p in problems:
        print("CHANGED:", p)
    for n in notes:
        print("new:", n)
    print(f"{len(problems)} changed or lost, {len(notes)} new")
    sys.exit(1 if problems else 0)


main()
