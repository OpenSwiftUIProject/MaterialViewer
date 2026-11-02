#!/usr/bin/env python3
"""Check CLI behavior after copying the binary outside its app and checkout."""

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path


def check(binary):
    with tempfile.TemporaryDirectory(prefix="materialviewer-cli-") as directory:
        cli = Path(directory) / "materialviewer"
        shutil.copy2(binary, cli)

        def run(arguments, expected_status):
            result = subprocess.run(
                [str(cli), *arguments], cwd=directory, capture_output=True,
                text=True, timeout=30,
            )
            assert result.returncode == expected_status, (
                f"{arguments}: expected exit {expected_status}, got "
                f"{result.returncode}\n{result.stdout}\n{result.stderr}"
            )
            return result

        for arguments in ([], ["--help"], ["-h"]):
            result = run(arguments, 0)
            assert result.stdout.startswith("Usage: materialviewer ")
            assert not result.stderr

        for arguments in (["--invalid"], ["--check", "--invalid"], ["a", "b"]):
            result = run(arguments, 2)
            assert "Usage: materialviewer " in result.stderr

        result = run(["--check", str(Path(directory) / "missing.materialrecipe")], 1)
        assert "File not found:" in result.stderr
        result = run(["--check", directory], 1)
        assert "No material recipes found." in result.stderr

        result = run(["--check"], 0)
        output = result.stdout.lstrip()
        reports = []
        decoder = json.JSONDecoder()
        while output.startswith("{"):
            report, end = decoder.raw_decode(output)
            assert report["file"] and report["layer"] and not report["warnings"]
            reports.append(report)
            output = output[end:].lstrip()
        assert reports
        assert output.strip() == f"Checked {len(reports)} recipes; 0 failures."
        print(f"CLI checks passed; {len(reports)} system recipes loaded.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    check(parser.parse_args().binary.resolve())
