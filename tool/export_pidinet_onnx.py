#!/usr/bin/env python3
"""Export the official PiDiNet checkpoint to an app-local ONNX model.

The generated ONNX file is intentionally ignored by Git, matching the existing
DexiNed model policy. This script records and verifies the source checkpoint so
the model can be reproduced in another environment.

Usage:
  python3 -m pip install onnx
  python3 tool/export_pidinet_onnx.py
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from types import SimpleNamespace

import torch


REPO_ARCHIVE_URL = "https://github.com/hellozhuo/pidinet/archive/refs/heads/master.zip"
CHECKPOINT_URL = (
    "https://github.com/hellozhuo/pidinet/raw/master/"
    "trained_models/table5_pidinet.pth"
)
CHECKPOINT_SHA256 = (
    "80860ac267258b5f27486e0ef152a211d0b08120f62aeb185a050acc30da486c"
)
OUTPUT = Path("assets/models/pidinet_table5_carv4_ort.onnx")
INPUT_NAME = "input"
OUTPUT_NAME = "edge"
MODEL_HEIGHT = 480
MODEL_WIDTH = 640


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()

    if args.output.exists() and not args.force:
        print(f"PiDiNet ONNX already exists: {args.output}")
        return 0

    try:
        import onnx  # noqa: F401
    except ModuleNotFoundError:
        print("Missing Python dependency: onnx", file=sys.stderr)
        print("Install it with: python3 -m pip install onnx", file=sys.stderr)
        return 69

    with tempfile.TemporaryDirectory(prefix="pidinet_export_") as tmp:
        tmp_dir = Path(tmp)
        repo_dir = _download_repo(tmp_dir)
        checkpoint = args.checkpoint or _download_checkpoint(tmp_dir)
        _verify_sha256(checkpoint, CHECKPOINT_SHA256)
        _export(repo_dir, checkpoint, args.output)

    print(f"Saved PiDiNet ONNX model: {args.output}")
    return 0


def _download_repo(tmp_dir: Path) -> Path:
    archive = tmp_dir / "pidinet-master.zip"
    print("Downloading PiDiNet source archive...")
    urllib.request.urlretrieve(REPO_ARCHIVE_URL, archive)
    with zipfile.ZipFile(archive) as source_zip:
        source_zip.extractall(tmp_dir)
    repo_dir = tmp_dir / "pidinet-master"
    if not repo_dir.exists():
        raise RuntimeError("PiDiNet source archive did not contain pidinet-master")
    return repo_dir


def _download_checkpoint(tmp_dir: Path) -> Path:
    checkpoint = tmp_dir / "table5_pidinet.pth"
    print("Downloading PiDiNet table5 checkpoint...")
    urllib.request.urlretrieve(CHECKPOINT_URL, checkpoint)
    return checkpoint


def _verify_sha256(path: Path, expected: str) -> None:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        raise RuntimeError(
            f"SHA256 mismatch for {path}: expected {expected}, actual {digest}"
        )


def _export(repo_dir: Path, checkpoint: Path, output: Path) -> None:
    sys.path.insert(0, str(repo_dir))
    import models  # type: ignore
    from models.convert_pidinet import convert_pidinet  # type: ignore

    model_args = SimpleNamespace(model="pidinet_converted", config="carv4", sa=True, dil=True)
    model = models.pidinet_converted(model_args)

    loaded = torch.load(checkpoint, map_location="cpu")
    state_dict = loaded["state_dict"] if "state_dict" in loaded else loaded
    converted = convert_pidinet(state_dict, model_args.config)
    converted = {
        key.removeprefix("module."): value for key, value in converted.items()
    }
    model.load_state_dict(converted)
    model.eval()

    dummy = torch.zeros(1, 3, MODEL_HEIGHT, MODEL_WIDTH, dtype=torch.float32)
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp_output = output.with_suffix(".onnx.download")
    if tmp_output.exists():
        tmp_output.unlink()

    torch.onnx.export(
        model,
        dummy,
        tmp_output,
        export_params=True,
        opset_version=17,
        do_constant_folding=True,
        input_names=[INPUT_NAME],
        output_names=[OUTPUT_NAME],
        dynamic_axes=None,
    )

    import onnx

    onnx_model = onnx.load(tmp_output)
    onnx.checker.check_model(onnx_model)
    if output.exists():
        output.unlink()
    shutil.move(str(tmp_output), output)


if __name__ == "__main__":
    raise SystemExit(main())
