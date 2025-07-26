from importlib.metadata import entry_points
from itertools import chain
import json
import sys
from typing import List, TypedDict


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
        if sys.version_info >= (3, 11):
            eps = entry_points()
        else:
            eps = chain(*entry_points().values())

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
