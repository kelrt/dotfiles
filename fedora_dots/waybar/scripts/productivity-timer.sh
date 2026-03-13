#!/bin/bash
# Productivity Timer for Waybar
# Auto-progresses through segments, hover to see what's next

STATE_FILE="/tmp/productivity-timer-state"

# Segment order: type:duration_seconds:next_label
SEGMENTS=(
    "work:1800:Journal Break"
    "break:300:Work"
    "work:1800:Journal Break"
    "break:300:Work"
    "work:1800:Workout #1"
    "workout:300:Work"
    "work:1800:Journal Break"
    "break:300:Work"
    "work:1800:Workout #2"
    "workout:300:Work"
    "work:1800:Journal Break"
    "break:300:Work"
    "work:1800:Workout #3"
    "workout:300:Work"
    "work:1800:Journal Break"
    "break:300:Work"
    "work:1800:Workout #4"
    "workout:300:Done!"
)

TOTAL_SEGMENTS=${#SEGMENTS[@]}

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo "running|0|0" > "$STATE_FILE"
fi

get_state() {
    cat "$STATE_FILE"
}

set_state() {
    echo "$1|$2|$3" > "$STATE_FILE"
}

print_schedule() {
    local current_idx=$1
    local i=0
    for seg in "${SEGMENTS[@]}"; do
        IFS=':' read -r seg_type _ _ <<< "$seg"
        if [[ $i -eq $current_idx ]]; then
            echo "[x] $seg_type"
        else
            echo "[ ] $seg_type"
        fi
        ((i++))
    done
}

case "$1" in
    toggle)
        IFS='|' read -r status elapsed segment_idx <<< "$(get_state)"
        if [[ "$status" == "running" ]]; then
            set_state "paused" "$elapsed" "$segment_idx"
        else
            set_state "running" "$elapsed" "$segment_idx"
        fi
        ;;
    reset)
        set_state "running" "0" "0"
        echo "Reset to beginning"
        echo ""
        print_schedule 0
        ;;
    next)
        IFS='|' read -r status elapsed segment_idx <<< "$(get_state)"
        next_idx=$(( (segment_idx + 1) % TOTAL_SEGMENTS ))
        set_state "$status" "0" "$next_idx"
        echo "Skipped to next segment"
        echo ""
        print_schedule "$next_idx"
        ;;
    tick)
        IFS='|' read -r status elapsed segment_idx <<< "$(get_state)"
        if [[ "$status" == "running" ]]; then
            IFS=':' read -r seg_type seg_duration next_label <<< "${SEGMENTS[$segment_idx]}"
            elapsed=$((elapsed + 1))
            
            if [[ $elapsed -ge $seg_duration ]]; then
                next_idx=$(( (segment_idx + 1) % TOTAL_SEGMENTS ))
                IFS=':' read -r next_type _ _ <<< "${SEGMENTS[$next_idx]}"
                
                case "$next_type" in
                    work)    notify-send "🎯 Work Time" "Focus for 30 minutes" ;;
                    break)   notify-send "📝 Journal Break" "3 min journal + 2 min move" ;;
                    workout) 
                        IFS=':' read -r _ _ workout_label <<< "${SEGMENTS[$segment_idx]}"
                        notify-send -u critical "🏋️ $workout_label" "Time to work out!" 
                        ;;
                esac
                
                set_state "running" "0" "$next_idx"
            else
                set_state "running" "$elapsed" "$segment_idx"
            fi
        fi
        ;;
    *)
        IFS='|' read -r status elapsed segment_idx <<< "$(get_state)"
        IFS=':' read -r seg_type seg_duration next_label <<< "${SEGMENTS[$segment_idx]}"
        
        remaining=$((seg_duration - elapsed))
        mins=$((remaining / 60))
        secs=$((remaining % 60))
        
        if [[ "$status" == "paused" ]]; then
            printf '{"text": "⏸ %02d:%02d", "class": "paused", "tooltip": "Next: %s"}\n' "$mins" "$secs" "$next_label"
        else
            printf '{"text": "%02d:%02d", "class": "%s", "tooltip": "Next: %s"}\n' "$mins" "$secs" "$seg_type" "$next_label"
        fi
        ;;
esac
