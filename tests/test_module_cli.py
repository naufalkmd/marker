import sys
from types import SimpleNamespace

from marker import __main__


class FakeClickCommand:
    def __init__(self):
        self.calls = []

    def main(self, args, prog_name, standalone_mode):
        self.calls.append(
            {
                "args": args,
                "prog_name": prog_name,
                "standalone_mode": standalone_mode,
            }
        )
        return "ok"


def test_main_dispatches_to_default_click_entrypoint(monkeypatch):
    command = FakeClickCommand()

    def fake_import(module_name):
        assert module_name == "marker.scripts.convert"
        return SimpleNamespace(convert_cli=command)

    monkeypatch.setattr(__main__.importlib, "import_module", fake_import)

    result = __main__.main(["inbox", "--output_format", "markdown"])

    assert result == "ok"
    assert command.calls == [
        {
            "args": ["inbox", "--output_format", "markdown"],
            "prog_name": "python -m marker",
            "standalone_mode": False,
        }
    ]


def test_main_dispatches_to_subcommand_and_restores_argv(monkeypatch):
    original_argv = sys.argv[:]
    seen = []

    def fake_gui():
        seen.append(sys.argv[:])
        return "gui"

    def fake_import(module_name):
        assert module_name == "marker.scripts.run_streamlit_app"
        return SimpleNamespace(streamlit_app_cli=fake_gui)

    monkeypatch.setattr(__main__.importlib, "import_module", fake_import)

    result = __main__.main(["gui", "--server.port", "8501"])

    assert result == "gui"
    assert seen == [["python -m marker gui", "--server.port", "8501"]]
    assert sys.argv == original_argv
