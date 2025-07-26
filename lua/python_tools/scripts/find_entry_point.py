from importlib import metadata
from inspect import getsourcefile, getsourcelines
import json
import sys
from typing import TypedDict


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
        ep = next(iter(ep))
    else:
        ep = None
        for candidate in metadata.entry_points()[group]:
            if candidate.name == name:
                ep = candidate
                break

        if ep is None:
            raise ValueError("Could not find Entrypoint.")

    ep_func = ep.load()
    file_name = getsourcefile(ep_func)
    if not file_name:
        raise ValueError("Cannot find source file!")

    result = Entrypoint(
        name=ep.name,
        group=ep.group,
        filename=file_name,
        lineno=getsourcelines(ep_func)[1],
    )

    print(json.dumps(result, separators=(",", ":")), end="")
