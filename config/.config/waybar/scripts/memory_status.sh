#!/bin/bash

# Get memory info
MEM_INFO=$(free -h | awk 'NR==2{gsub(/Gi/, "GB", $3); gsub(/Gi/, "GB", $2); print $3"/"$2}')
MEM_PERCENT=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

# Get top 10 memory consuming processes with memory in GB
TOP_PROCS=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=11{
  # Extract just the command name (basename) without arguments
  split($11, path, "/")
  cmd=path[length(path)]
  # Convert RSS (in KB) to GB
  mem_gb=$6/1024/1024
  printf "%s: %.2fGB\\n", cmd, mem_gb
}')

# Determine color class based on memory usage
if ((MEM_PERCENT >= 80)); then
  CLASS="high"
elif ((MEM_PERCENT >= 50)); then
  CLASS="medium"
else
  CLASS="low"
fi

# Format display text
TEXT="💾 $MEM_INFO"

# Create tooltip with top processes
TOOLTIP="Memory Usage: ${MEM_PERCENT}%\\n\\nTop Memory Consumers:\\n${TOP_PROCS}"

# Output JSON for waybar
echo "{\"text\": \"$TEXT\", \"tooltip\": \"$TOOLTIP\", \"class\": \"$CLASS\"}"
