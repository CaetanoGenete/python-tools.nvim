from typing import Callable


def decorator(func: Callable[[], None]) -> Callable[[], None]:
    def wrapper() -> None:
        func()

    return wrapper


@decorator
def entry_point() -> None:
    pass
