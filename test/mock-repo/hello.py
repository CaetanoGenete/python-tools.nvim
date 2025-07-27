class EntryPointClass:
    def entry_point(self) -> None:
        pass


def entry_point_1() -> None:
    pass


def _entry_point_2() -> None:
    pass


entry_point_2 = _entry_point_2

ep = EntryPointClass()
