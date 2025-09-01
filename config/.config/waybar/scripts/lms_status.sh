#!/bin/bash

# Check if LM Studio is running
if ! pgrep -f "lm-studio" > /dev/null; then
  echo '{"text": "🧠 No LLM", "tooltip": "LM Studio not running", "class": "inactive"}'
  exit 0
fi

# Get GPU information
GPU_INFO=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)

if [[ -z "$GPU_INFO" ]]; then
  echo '{"text": "🧠 LLM ❌GPU", "tooltip": "LM Studio running but GPU info unavailable", "class": "warning"}'
  exit 0
fi

# Parse GPU info
IFS=',' read -r GPU_NAME GPU_UTIL GPU_MEM_USED GPU_MEM_TOTAL <<< "$GPU_INFO"
GPU_NAME=$(echo "$GPU_NAME" | xargs)
GPU_UTIL=$(echo "$GPU_UTIL" | xargs)
GPU_MEM_USED=$(echo "$GPU_MEM_USED" | xargs)
GPU_MEM_TOTAL=$(echo "$GPU_MEM_TOTAL" | xargs)

# Calculate memory usage in GB
GPU_MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_USED/1024}")
GPU_MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_MEM_TOTAL/1024}")

# Get current model from LM Studio API
CURRENT_MODEL=""
API_RESPONSE=$(curl -s http://localhost:1234/v1/models 2>/dev/null)
if [[ -n "$API_RESPONSE" ]]; then
  # Try to get the first available model as a proxy for current model
  CURRENT_MODEL=$(echo "$API_RESPONSE" | jq -r '.data[0].id // ""' 2>/dev/null)
  if [[ "$CURRENT_MODEL" && "$CURRENT_MODEL" != "null" ]]; then
    # Extract model name (remove organization prefix if present)
    CURRENT_MODEL=$(echo "$CURRENT_MODEL" | sed 's|.*/||' | cut -d'-' -f1-2)
  else
    CURRENT_MODEL=""
  fi
fi

# Determine color class based on GPU utilization
if ((GPU_UTIL >= 80)); then
  CLASS="high"
elif ((GPU_UTIL >= 50)); then
  CLASS="medium"
else
  CLASS="low"
fi

# Format display text
if [[ -n "$CURRENT_MODEL" ]]; then
  TEXT="🧠 $CURRENT_MODEL 🖥️ ${GPU_MEM_USED_GB}/${GPU_MEM_TOTAL_GB}GB"
else
  TEXT="🧠 LLM 🖥️ ${GPU_MEM_USED_GB}/${GPU_MEM_TOTAL_GB}GB"
fi

# Create tooltip
TOOLTIP="Model: ${CURRENT_MODEL:-"Unknown"}\\nGPU: $GPU_NAME\\nUtilization: ${GPU_UTIL}%\\nMemory: ${GPU_MEM_USED_GB}GB / ${GPU_MEM_TOTAL_GB}GB"

# Output JSON for waybar
echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"