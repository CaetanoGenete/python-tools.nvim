from itertools import chain
import json
import sys

EXIT_OK = 0
EXIT_FAIL_UNEXPECTED = 1
EXIT_FAIL_IMPORT_IMPORTLIB = 2
EXIT_FAIL_PYTHON_VERSION = 3

if sys.version_info < (3, 8):
    sys.exit(EXIT_FAIL_PYTHON_VERSION)
else:
    from typing import List, TypedDict

try:
    from importlib.metadata import entry_points
except Exception:
    sys.exit(EXIT_FAIL_IMPORT_IMPORTLIB)


class EntryPoint(TypedDict):
    name: str
    group: str
    value: List[str]


if __name__ == "__main__":
    group = sys.argv[1] if len(sys.argv) > 1 else None

    if group:
        if sys.version_info >= (3, 10):
            eps = entry_points(group=group)
        else:
            eps = entry_points().get(group, [])
    else:
        if sys.version_info >= (3, 12):
            eps = entry_points()
        else:
            eps = chain(*entry_points().values())

    # Python versions less than 3.10 may duplicate imports. See
    # https://github.com/pypa/setuptools/issues/3649
    if sys.version_info < (3, 10):
        eps = set(eps)

    result = [
        EntryPoint(
            name=ep.name,
            group=ep.group,
            value=ep.value.split(":"),
        )
        for ep in eps
    ]

    # Serialise output to compact json
    print(json.dumps(result, separators=(",", ":")))
