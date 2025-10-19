from setuptools import setup

_ = setup(
    name="mock-setup_py-repo",
    version="0.1.0",
    entry_points={
        "console_scripts": [
            "ep1=hello:ep1",
        ],
        "other": [
            "ep2=hello:ep2",
        ],
    },
)
