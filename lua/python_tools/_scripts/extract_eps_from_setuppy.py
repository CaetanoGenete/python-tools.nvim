import json
import sys
from typing import Any, Dict, List, TypedDict
from importlib.util import spec_from_file_location, module_from_spec

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
    ep, value = entry.split("=", 1)

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

spec = spec_from_file_location("setuppy_module", sys.argv[1])
if spec is None:
    sys.exit(2)

foo = module_from_spec(spec)

if spec.loader is None:
    sys.exit(3)

spec.loader.exec_module(foo)
