from inspect import getsourcefile, getsourcelines
import json
import sys

EXIT_OK = 0
EXIT_FAIL_UNEXPECTED = 1
EXIT_FAIL_IMPORT_IMPORTLIB = 2
EXIT_FAIL_FIND_ENTRY_POINT = 3
EXIT_FAIL_RESOLVE_SOURCE_FILE = 4
EXIT_FAIL_RESOLVE_SOURCE_LINE = 5
EXIT_FAIL_PYTHON_VERSION = 6

if sys.version_info < (3, 8):
    sys.exit(EXIT_FAIL_PYTHON_VERSION)
else:
    from typing import TypedDict

try:
    from importlib import metadata
except Exception:
    sys.exit(EXIT_FAIL_IMPORT_IMPORTLIB)


class Entrypoint(TypedDict):
    name: str
    group: str
    filename: str
    lineno: int


if __name__ == "__main__":
    name, group = sys.argv[1:]

    if sys.version_info >= (3, 10):
        ep = metadata.entry_points(
            name=name,
            group=group,
        )
        if len(ep) == 0:
            ep = None
        else:
            ep = next(iter(ep))
    else:
        ep = None
        for candidate in metadata.entry_points()[group]:
            if candidate.name == name:
                ep = candidate
                break

    if ep is None:
        sys.exit(EXIT_FAIL_FIND_ENTRY_POINT)

    try:
        ep_func = ep.load()
        file_name = getsourcefile(ep_func)
    except Exception:
        sys.exit(EXIT_FAIL_RESOLVE_SOURCE_FILE)

    if not file_name:
        sys.exit(EXIT_FAIL_RESOLVE_SOURCE_FILE)

    try:
        lineno = getsourcelines(ep_func)[1]
    except Exception:
        sys.exit(EXIT_FAIL_RESOLVE_SOURCE_LINE)

    result = Entrypoint(
        name=ep.name,
        group=ep.group,
        filename=file_name,
        lineno=lineno,
    )

    print(json.dumps(result, separators=(",", ":")), end="")
