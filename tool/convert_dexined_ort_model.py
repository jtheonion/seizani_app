#!/usr/bin/env python3
"""Create an ONNX Runtime-compatible DexiNed model.

The OpenCV DexiNed ONNX model is block-quantized and can fail on mobile ORT
builds at DequantizeLinear nodes. This script folds constant DequantizeLinear
nodes into fp32 initializers so the app can run the same network with the CPU
provider on-device.

Usage:
  python3 -m pip install onnx
  python3 tool/convert_dexined_ort_model.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import onnx
from onnx import helper, numpy_helper


SOURCE = Path("assets/models/edge_detection_dexined_2024sep.onnx")
DESTINATION = Path("assets/models/edge_detection_dexined_2024sep_ort.onnx")


def _attribute(node: onnx.NodeProto, name: str, default):
    for attribute in node.attribute:
        if attribute.name == name:
            return helper.get_attribute_value(attribute)
    return default


def _expand_quant_param(
    value: np.ndarray,
    x_shape: tuple[int, ...],
    axis: int,
    block_size: int,
) -> np.ndarray:
    if value.ndim == 0 or value.size == 1:
        return value

    if axis < 0:
        axis += len(x_shape)

    if block_size > 0 and value.shape[axis] != x_shape[axis]:
        value = np.repeat(value, block_size, axis=axis)
        slices = [slice(None)] * value.ndim
        slices[axis] = slice(0, x_shape[axis])
        value = value[tuple(slices)]

    return value


def main() -> None:
    model = onnx.load(SOURCE)
    initializers = {initializer.name: initializer for initializer in model.graph.initializer}

    new_nodes: list[onnx.NodeProto] = []
    folded_count = 0

    for node in model.graph.node:
        if (
            node.op_type != "DequantizeLinear"
            or len(node.input) < 2
            or node.input[0] not in initializers
            or node.input[1] not in initializers
        ):
            new_nodes.append(node)
            continue

        x = numpy_helper.to_array(initializers[node.input[0]])
        scale = numpy_helper.to_array(initializers[node.input[1]])
        zero_point = np.array(0, dtype=x.dtype)
        if len(node.input) > 2 and node.input[2] in initializers:
            zero_point = numpy_helper.to_array(initializers[node.input[2]])

        axis = _attribute(node, "axis", 1)
        block_size = _attribute(node, "block_size", 0)
        scale = _expand_quant_param(scale, x.shape, axis, block_size)
        zero_point = _expand_quant_param(zero_point, x.shape, axis, block_size)

        folded = (x.astype(np.float32) - zero_point.astype(np.float32)) * scale.astype(
            np.float32
        )
        model.graph.initializer.append(
            numpy_helper.from_array(folded.astype(np.float32), name=node.output[0])
        )
        folded_count += 1

    del model.graph.node[:]
    model.graph.node.extend(new_nodes)

    used_initializer_names = set()
    for node in model.graph.node:
        used_initializer_names.update(node.input)
    used_initializer_names.update(output.name for output in model.graph.output)

    kept_initializers = [
        initializer
        for initializer in model.graph.initializer
        if initializer.name in used_initializer_names
    ]
    del model.graph.initializer[:]
    model.graph.initializer.extend(kept_initializers)

    onnx.checker.check_model(model)
    onnx.save(model, DESTINATION)
    print(
        f"Saved {DESTINATION} after folding {folded_count} DequantizeLinear nodes."
    )


if __name__ == "__main__":
    main()
