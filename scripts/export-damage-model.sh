#!/usr/bin/env bash
# Export the free YOLO11n car-damage model for on-device use.
# Source: https://huggingface.co/vineetsarpal/yolov11n-car-damage
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/mobile/assets/models"
mkdir -p "$OUT"

export OUT="$OUT"
python3 - <<PY
import os, shutil
from huggingface_hub import hf_hub_download
from ultralytics import YOLO

out_dir = os.environ['OUT']
pt = hf_hub_download('vineetsarpal/yolov11n-car-damage', 'best.pt')
model = YOLO(pt)
onnx_path = model.export(format='onnx', imgsz=640)
out = os.path.join(out_dir, 'car_damage_yolo11n.onnx')
shutil.copy2(onnx_path, out)
print('Wrote', out, os.path.getsize(out), 'bytes')
PY
