from __future__ import annotations

import importlib
import sys
from dataclasses import dataclass
from typing import Callable


@dataclass(frozen=True)
class EntryPoint:
    module_name: str
    attribute: str
    uses_click: bool = True


DEFAULT_ENTRYPOINT = EntryPoint("marker.scripts.convert", "convert_cli")
SUBCOMMAND_ENTRYPOINTS = {
    "single": EntryPoint("marker.scripts.convert_single", "convert_single_cli"),
    "chunk": EntryPoint("marker.scripts.chunk_convert", "chunk_convert_cli", uses_click=False),
    "gui": EntryPoint("marker.scripts.run_streamlit_app", "streamlit_app_cli", uses_click=False),
    "extract": EntryPoint("marker.scripts.run_streamlit_app", "extraction_app_cli", uses_click=False),
    "server": EntryPoint("marker.scripts.server", "server_cli"),
}


def _load_handler(entrypoint: EntryPoint) -> Callable:
    module = importlib.import_module(entrypoint.module_name)
    return getattr(module, entrypoint.attribute)


def _run_click(handler: Callable, args: list[str], prog_name: str):
    return handler.main(args=args, prog_name=prog_name, standalone_mode=False)


def _run_argv(handler: Callable, args: list[str], prog_name: str):
    original_argv = sys.argv[:]
    try:
        sys.argv = [prog_name, *args]
        return handler()
    finally:
        sys.argv = original_argv


def main(argv: list[str] | None = None):
    args = list(sys.argv[1:] if argv is None else argv)
    prog_name = "python -m marker"
    entrypoint = DEFAULT_ENTRYPOINT

    if args and args[0] in SUBCOMMAND_ENTRYPOINTS:
        subcommand = args.pop(0)
        entrypoint = SUBCOMMAND_ENTRYPOINTS[subcommand]
        prog_name = f"{prog_name} {subcommand}"

    handler = _load_handler(entrypoint)
    runner = _run_click if entrypoint.uses_click else _run_argv
    return runner(handler, args, prog_name)


if __name__ == "__main__":
    raise SystemExit(main())
