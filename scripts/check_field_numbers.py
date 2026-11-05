#!/usr/bin/env python3
"""Check the field numbers in src/ against etcd's own .proto files.

A round trip through our own encoder and decoder cannot catch a wrong number, and a field nobody
reads against a real server looks fine for ever, so the numbers are compared with the source.

The HTTP/JSON gateway names the same fields in text, so the tables in `src/gateway_fields_*.mbt`
are checked the same way: the number, the name, the kind, and the enumeration names, against the
same .proto files.

    python3 scripts/check_field_numbers.py [tag]
"""
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = "https://raw.githubusercontent.com/etcd-io/etcd/{tag}/{path}"
FILES = [
    "api/etcdserverpb/rpc.proto",
    "api/mvccpb/kv.proto",
    "api/authpb/auth.proto",
    "server/etcdserver/api/v3lock/v3lockpb/v3lock.proto",
    "server/etcdserver/api/v3election/v3electionpb/v3election.proto",
]
# Fields of a newer etcd than the tag, kept so a newer server's answer is not dropped, and the one
# value that stands for the arms of a oneof, whose numbers the decoder spells out.
EXEMPT = {"HashKVResponse.hash_revision", "Compare.target_union"}
# Names that say more here than the wire's oneof member does.
RENAMED = {"event_type": "type"}
# Messages the gateway table may leave out: they carry no field the client reads or writes.
GATEWAY_SKIP = {"LeaseCheckpointRequest", "LeaseCheckpointResponse", "LeaseCheckpoint"}
# A message the gateway names differently from the .proto, because two packages declare one.
GATEWAY_ALIAS = {"Permission": "Permission", "Type": "PermissionType"}
# The .proto spelling of each kind the table can name.
SCALARS = {
    "Str": "string",
    "Bytes": "bytes",
    "Bool": "bool",
    "Int32": "int32",
    "Int64": "int64",
    "UInt32": "uint32",
    "UInt64": "uint64",
}


def messages(text):
    """Message name to {normalised field name: number}."""
    found, stack = {}, []
    for raw in text.splitlines():
        line = re.sub(r"//.*", "", raw).strip()
        if m := re.match(r"message\s+(\w+)\s*\{", line):
            stack.append(m.group(1))
            found.setdefault(m.group(1), {})
        elif line.startswith("enum "):
            stack.append(None)
        elif line.startswith("oneof "):
            stack.append(stack[-1])
        elif line.startswith("}"):
            if stack:
                stack.pop()
        elif stack and stack[-1]:
            if f := re.match(r"(?:repeated\s+)?[\w.]+\s+(\w+)\s*=\s*(\d+)", line):
                found[stack[-1]][normal(f.group(1))] = int(f.group(2))
    return found


def shapes(text):
    """Message name to {field name: (number, kind, repeated)}, and enum name to its values."""
    found, enums, stack = {}, {}, []
    for raw in text.splitlines():
        line = re.sub(r"//.*", "", raw).strip()
        if m := re.match(r"message\s+(\w+)\s*\{", line):
            stack.append(("message", m.group(1)))
            found.setdefault(m.group(1), {})
        elif m := re.match(r"enum\s+(\w+)\s*\{", line):
            stack.append(("enum", m.group(1)))
            enums.setdefault(m.group(1), {})
        elif m := re.match(r"oneof\s+(\w+)\s*\{", line):
            stack.append(("oneof", stack[-1][1]))
        elif line.startswith("}"):
            if stack:
                stack.pop()
        elif stack:
            kind, owner = stack[-1]
            if kind == "enum":
                if e := re.match(r"(\w+)\s*=\s*(-?\d+)", line):
                    enums[owner][int(e.group(2))] = e.group(1)
            elif f := re.match(r"(repeated\s+)?([\w.]+)\s+(\w+)\s*=\s*(\d+)", line):
                found[owner][f.group(3)] = (
                    int(f.group(4)),
                    f.group(2).split(".")[-1],
                    bool(f.group(1)),
                )
    return found, enums


def normal(name):
    return name.replace("_", "").lower()


def gateway_kind(kind):
    """The table's spelling of a kind as (proto type, repeated, enum names or None)."""
    repeated = False
    if kind.startswith("Rep(") and kind.endswith(")"):
        repeated = True
        kind = kind[4:-1]
    kind = kind.strip()
    if kind in SCALARS:
        return SCALARS[kind], repeated, None
    if m := re.fullmatch(r'Enum\(\[(.*)\]\)', kind):
        names = [n.strip().strip('"') for n in m.group(1).split(",") if n.strip()]
        return "enum", repeated, names
    if m := re.fullmatch(r'Message\("(\w+)"\)', kind):
        return m.group(1), repeated, None
    raise SystemExit(f"the table names a kind this script does not know: {kind}")


def gateway_rows():
    """Message name to [(number, name, kind, presence)], in file order.

    A long field is written over several lines by the formatter, so the table is
    scanned as one text rather than line by line; a kind never contains a brace, so
    the row ends at the first one after it.
    """
    rows = {}
    pattern = re.compile(
        r'"(\w+)" =>|\{\s*number: (\d+),\s*name: "(\w+)",\s*kind: ([^{}]*?),\s*'
        r"presence: (true|false),?\s*\}",
        re.S,
    )
    for path in sorted((ROOT / "src").glob("gateway_fields_*.mbt")):
        text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
        message = None
        for m in pattern.finditer(text):
            if m.group(1):
                message = m.group(1)
                rows.setdefault(message, [])
            elif message:
                rows[message].append(
                    (int(m.group(2)), m.group(3), " ".join(m.group(4).split()), m.group(5))
                )
    return rows


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else "v3.5.16"
    texts = []
    for path in FILES:
        with urllib.request.urlopen(BASE.format(tag=tag, path=path), timeout=60) as reply:
            texts.append(reply.read().decode())
    proto = {}
    for text in texts:
        proto.update(messages(text))
    source = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "src").glob("*.mbt"))
    source = source.replace("\r\n", "\n")
    wrong = []
    patterns = {
        "encode": r"\bw\.\w+\(\s*(\d+),\s*(?:[\w.@:]+\()?self\.(\w+)",
        "decode": r"\((\d+),\s*\w+\)\s*=>\s*[^\n]*?\.\.\w+,\s*(\w+):",
    }
    checked = 0
    for kind, pattern in patterns.items():
        for fn in re.finditer(rf"fn (\w+)::{kind}\(.*?\n}}\n", source, re.S):
            name = fn.group(1)
            if name not in proto:
                continue
            for number, field in re.findall(pattern, fn.group(0)):
                if f"{name}.{field}" in EXEMPT:
                    continue
                checked += 1
                wanted = proto[name].get(normal(RENAMED.get(field, field)))
                if wanted is None:
                    wrong.append(f"{name}.{field}: etcd has no such field")
                elif wanted != int(number):
                    wrong.append(f"{name}.{field}: {number} here, {wanted} in etcd {tag}")
    print(f"{checked} field uses checked against {len(proto)} messages of etcd {tag}")

    shapes_of = {}
    enums_of = {}
    for text in texts:
        found, enums = shapes(text)
        shapes_of.update(found)
        enums_of.update({k: v for k, v in enums.items() if k not in enums_of})

    rows = gateway_rows()
    gateway_checked = 0
    for message, fields in sorted(rows.items()):
        name = GATEWAY_ALIAS.get(message, message)
        if name not in shapes_of:
            wrong.append(f"gateway {message}: etcd has no such message")
            continue
        declared = shapes_of[name]
        seen = set()
        for number, field, kind, presence in fields:
            gateway_checked += 1
            seen.add(field)
            if field not in declared:
                wrong.append(f"gateway {message}.{field}: etcd {tag} has no such field")
                continue
            want_number, want_type, want_repeated = declared[field]
            if want_number != number:
                wrong.append(
                    f"gateway {message}.{field}: number {number} here, {want_number} in etcd {tag}"
                )
            got_type, got_repeated, enum_names = gateway_kind(kind)
            if got_repeated != want_repeated:
                wrong.append(f"gateway {message}.{field}: repeated differs from etcd {tag}")
            if want_type in enums_of:
                if got_type != "enum":
                    wrong.append(f"gateway {message}.{field}: an enumeration here, {want_type} there")
                else:
                    values = enums_of[want_type]
                    if len(enum_names) <= max(values):
                        wrong.append(f"gateway {message}.{field}: too few enumeration names")
                    for index, value in values.items():
                        if index < len(enum_names) and enum_names[index] != value:
                            wrong.append(
                                f"gateway {message}.{field}: enum {index} is "
                                f"{enum_names[index]} here, {value} in etcd {tag}"
                            )
            elif got_type != want_type:
                wrong.append(
                    f"gateway {message}.{field}: kind {got_type} here, {want_type} in etcd {tag}"
                )
        for field in declared:
            if field not in seen:
                wrong.append(f"gateway {message}.{field}: in etcd {tag} but not in the table")
    print(f"{gateway_checked} gateway fields checked against {len(rows)} messages")

    for line in sorted(set(wrong)):
        print(line)
    sys.exit(1 if wrong else 0)


if __name__ == "__main__":
    main()
