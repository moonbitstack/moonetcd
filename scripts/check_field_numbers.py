#!/usr/bin/env python3
"""Check the field numbers in src/ against etcd's own .proto files.

A round trip through our own encoder and decoder cannot catch a wrong number, and a field nobody
reads against a real server looks fine for ever, so the numbers are compared with the source.

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


def normal(name):
    return name.replace("_", "").lower()


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else "v3.5.16"
    proto = {}
    for path in FILES:
        with urllib.request.urlopen(BASE.format(tag=tag, path=path), timeout=60) as reply:
            proto.update(messages(reply.read().decode()))
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
    for line in sorted(set(wrong)):
        print(line)
    sys.exit(1 if wrong else 0)


if __name__ == "__main__":
    main()
