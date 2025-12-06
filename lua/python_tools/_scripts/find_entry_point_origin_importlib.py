import sys

EXIT_OK = 0
EXIT_FAIL_UNEXPECTED = 1
EXIT_FAIL_IMPORT_IMPORTLIB = 2
EXIT_FAIL_FIND_ORIGIN = 3

try:
    from importlib.util import find_spec
except Exception:
    sys.exit(EXIT_FAIL_IMPORT_IMPORTLIB)

if __name__ == "__main__":
    spec_or_none = find_spec(sys.argv[1])
    if spec_or_none is not None:
        print(spec_or_none.origin, end="")
    else:
        sys.exit(EXIT_FAIL_FIND_ORIGIN)
