#!/bin/bash

if ! pgrep -f "ollama serve" > /dev/null 2>&1; then
  echo '{"text": "🤖 No Ollama", "tooltip": "Ollama not running", "class": "inactive"}'
  exit 0
fi

RUNNING=$(curl -s http://localhost:11434/api/ps 2>/dev/null)

if [[ -z "$RUNNING" ]] || [[ "$RUNNING" == "{}" ]]; then
  echo '{"text": "🤖 Ollama Idle", "tooltip": "Ollama running but no model loaded", "class": "idle"}'
  exit 0
fi

MODELS=$(echo "$RUNNING" | jq -r '.models[]?.name // ""' 2>/dev/null)

if [[ -z "$MODELS" ]] || [[ "$MODELS" == "null" ]]; then
  echo '{"text": "🤖 Ollama Idle", "tooltip": "Ollama running but no model loaded", "class": "idle"}'
  exit 0
fi

MODEL=$(echo "$MODELS" | head -1)
MODEL_SHORT=$(echo "$MODEL" | cut -d':' -f1)

SIZE_VRAM=$(echo "$RUNNING" | jq -r '.models[0].size_vram // 0' 2>/dev/null)
SIZE_VRAM_GB=$(awk "BEGIN {printf \"%.1f\", $SIZE_VRAM/1024/1024/1024}")

GPU_INFO=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)

if [[ -n "$GPU_INFO" ]]; then
  IFS=',' read -r GPU_UTIL GPU_MEM_USED GPU_MEM_TOTAL <<< "$GPU_INFO"
  GPU_UTIL=$(echo "$GPU_UTIL" | xargs)
  GPU_MEM_USED=$(echo "$GPU_MEM_USED" | xargs)
  GPU_MEM_TOTAL=$(echo "$GPU_MEM_TOTAL" | xargs)
  GPU_MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_USED/1024}")
  GPU_MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_TOTAL/1024}")
  GPU_TEXT=" 🖥️ ${GPU_MEM_USED_GB}/${GPU_MEM_TOTAL_GB}GB"
else
  GPU_TEXT=""
  GPU_UTIL=0
fi

if ((GPU_UTIL >= 80)); then
  CLASS="high"
elif ((GPU_UTIL >= 50)); then
  CLASS="medium"
else
  CLASS="low"
fi

TEXT="🤖 $MODEL_SHORT$GPU_TEXT"
TOOLTIP="Model: $MODEL\\nVRAM: ${SIZE_VRAM_GB}GB\\nGPU Util: ${GPU_UTIL}%\\nGPU Memory: ${GPU_MEM_USED_GB}GB / ${GPU_MEM_TOTAL_GB}GB"

echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
