
#!/usr/bin/env bash

# Target width of Samsung G9
TARGET_WIDTH=5120
LAYOUT_MASTER="master"
LAYOUT_OTHER="dwindle"

socat - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    if [[ "$line" =~ ^workspace>> ]]; then
        workspace=$(hyprctl activeworkspace -j | jq -r '.id')
        monitor=$(hyprctl activeworkspace -j | jq -r '.monitor')

        monitor_info=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor\")")
        width=$(echo "$monitor_info" | jq -r '.width')

        if [[ "$width" == "$TARGET_WIDTH" ]]; then
            hyprctl dispatch layoutmsg "$LAYOUT_MASTER:workspace $workspace"
        else
            hyprctl dispatch layoutmsg "$LAYOUT_OTHER:workspace $workspace"
        fi
    fi
done
