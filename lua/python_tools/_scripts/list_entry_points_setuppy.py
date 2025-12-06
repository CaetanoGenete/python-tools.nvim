import json
import sys

EXIT_OK = 0
EXIT_FAIL_UNEXPECTED = 1
EXIT_FAIL_EXEC_MODULE = 2
EXIT_PYTHON_VERSION = 3

if sys.version_info < (3, 8):
    sys.exit(EXIT_PYTHON_VERSION)
else:
    from typing import Any, Dict, List, TypedDict

try:
    import setuptools
except:

    class setuptools:
        @staticmethod
        def setup(**_): ...

        @staticmethod
        def find_packages(*_, **__):
            return []

        @staticmethod
        def find_namespace_packages(*_, **__):
            return []

    sys.modules["setuptools"] = setuptools


class EntryPoint(TypedDict):
    name: str
    group: str
    value: List[str]


def to_entry_point(group: str, entry: str) -> EntryPoint:
    ep, value = map(str.strip, entry.split("=", 1))

    return EntryPoint(
        group=group,
        name=ep.strip(),
        value=value.split(":"),
    )


def mock_setup(**args: Dict[str, Any]) -> None:
    eps: Dict[str, List[str]] = args.get("entry_points", {})

    if len(sys.argv) > 2:
        group = sys.argv[2]
        result = [to_entry_point(group, entry) for entry in eps.get(group, [])]
    else:
        result = [
            to_entry_point(group, entry)
            for group, entries in eps.items()
            for entry in entries
        ]

    print(json.dumps(result))


setuptools.setup = mock_setup

try:
    exec(sys.argv[1])
except Exception:
    sys.exit(EXIT_FAIL_EXEC_MODULE)
