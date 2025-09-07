from importlib.util import find_spec
import sys


if __name__ == "__main__":
    spec_or_none = find_spec(sys.argv[1])
    if spec_or_none is not None:
        print(spec_or_none.origin, end="")
    else:
        raise ValueError("No origin available.")
