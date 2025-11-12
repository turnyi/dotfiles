#!/usr/bin/env bash

# Health check script for eww
# Checks status of OptiTask services

check_service() {
  local url="$1"
  local name="$2"
  local service_icon="$3"
  
  # Try to fetch with 5 second timeout
  response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
  
  if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
    status="online"
    icon="✓"
    color="#9ece6a"
  else
    status="offline"
    icon="✗"
    color="#f7768e"
  fi
  
  echo "{\"name\":\"$name\",\"status\":\"$status\",\"icon\":\"$icon\",\"color\":\"$color\",\"code\":\"$response\",\"service_icon\":\"$service_icon\"}"
}

# Check all services
json_array="["

# Backend API (server icon)
back_status=$(check_service "https://api.opti-task.com/health" "Back" "🖥")
json_array+="$back_status,"

# Web Frontend (globe/browser icon)
web_status=$(check_service "https://opti-task.com" "Web" "🌐")
json_array+="$web_status,"

# Mobile Frontend (mobile phone icon)
mobile_status=$(check_service "https://mobile.opti-task.com" "Mobile" "📱")
json_array+="$mobile_status"

json_array+="]"

echo "$json_array"
