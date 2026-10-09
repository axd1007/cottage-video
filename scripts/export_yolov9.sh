#!/usr/bin/env bash
# Экспорт YOLOv9 в ONNX для Frigate (по документации Frigate, раздел Object Detectors -> ONNX).
# Использование: scripts/export_yolov9.sh [размер: t|s|m|c|e] [imgsz: 320|640]
# Результат: config/model_cache/yolov9-<размер>-<imgsz>.onnx
set -euo pipefail

MODEL_SIZE="${1:-t}"
IMG_SIZE="${2:-320}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/config/model_cache"
mkdir -p "$OUT"

docker build "$OUT" --build-arg MODEL_SIZE="$MODEL_SIZE" --build-arg IMG_SIZE="$IMG_SIZE" --output "$OUT" -f- <<'EOF'
FROM python:3.11 AS build
RUN apt-get update && apt-get install --no-install-recommends -y cmake libgl1 && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.10.4 /uv /bin/
ENV UV_HTTP_TIMEOUT=600
RUN uv pip install --system torch torchvision --index-url https://download.pytorch.org/whl/cpu
ENV UV_HTTP_TIMEOUT=600
RUN uv pip install --system torch torchvision --index-url https://download.pytorch.org/whl/cpu
ENV UV_HTTP_TIMEOUT=600
RUN uv pip install --system torch torchvision --index-url https://download.pytorch.org/whl/cpu
WORKDIR /yolov9
ADD https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system onnx==1.18.0 onnxruntime onnx-simplifier==0.4.* onnxscript
ARG MODEL_SIZE
ARG IMG_SIZE
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt
RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py
RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz ${IMG_SIZE} --simplify --include onnx
FROM scratch
ARG MODEL_SIZE
ARG IMG_SIZE
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx
EOF

ls -lh "$OUT/yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx"
