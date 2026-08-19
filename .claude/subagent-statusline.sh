#!/bin/bash
# subagentStatusLine — one row per visible subagent in the agent panel.
# Input: JSON on stdin with base hook fields + `columns` + `tasks[]`.
# Output: one JSON line per row to override: {"id": "...", "content": "..."}
input=$(cat)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; GRAY='\033[90m'; RESET='\033[0m'

COLUMNS_W=$(echo "$input" | jq -r '.columns // 80')
NOW_MS=$(date +%s000)

echo "$input" | jq -c '.tasks[]?' | while IFS= read -r task; do
  ID=$(echo "$task" | jq -r '.id')
  NAME=$(echo "$task" | jq -r '.name // .label // "agent"')
  TYPE=$(echo "$task" | jq -r '.type // empty')
  STATUS=$(echo "$task" | jq -r '.status // "running"')
  DESC=$(echo "$task" | jq -r '.description // empty')
  MODEL=$(echo "$task" | jq -r '.model // empty')
  START=$(echo "$task" | jq -r '.startTime // empty')
  TOKENS=$(echo "$task" | jq -r '.tokenCount // empty')
  CTX_SIZE=$(echo "$task" | jq -r '.contextWindowSize // empty')

  case "$STATUS" in
    running|in_progress) ICON="●"; COLOR="$CYAN" ;;
    pending|queued) ICON="○"; COLOR="$YELLOW" ;;
    completed|done|success) ICON="✔"; COLOR="$GREEN" ;;
    failed|error) ICON="✘"; COLOR="$RED" ;;
    *) ICON="●"; COLOR="$GRAY" ;;
  esac

  ELAPSED=""
  if [ -n "$START" ] && [ "$START" != "null" ]; then
    DIFF_MS=$((NOW_MS - START))
    [ "$DIFF_MS" -lt 0 ] && DIFF_MS=0
    MINS=$((DIFF_MS / 60000)); SECS=$(((DIFF_MS % 60000) / 1000))
    ELAPSED=" ${MINS}m${SECS}s"
  fi

  PCT=""
  if [ -n "$TOKENS" ] && [ "$TOKENS" != "null" ] && [ -n "$CTX_SIZE" ] && [ "$CTX_SIZE" != "null" ] && [ "$CTX_SIZE" -gt 0 ]; then
    PCT=" $((TOKENS * 100 / CTX_SIZE))%ctx"
  fi

  LABEL="$NAME"
  [ -n "$TYPE" ] && LABEL="$LABEL:$TYPE"

  # Fixed part (icon+label+elapsed+pct+model), plain-text length, drives how much
  # room is left for the variable-length description.
  FIXED="$ICON $LABEL$ELAPSED$PCT"
  [ -n "$MODEL" ] && FIXED="$FIXED [$MODEL]"

  if [ -n "$DESC" ]; then
    BUDGET=$((COLUMNS_W - ${#FIXED} - 3))
    if [ "$BUDGET" -gt 0 ] && [ "${#DESC}" -gt "$BUDGET" ]; then
      DESC="${DESC:0:$BUDGET}..."
    fi
  fi

  ROW="${COLOR}${ICON}${RESET} ${LABEL}${ELAPSED}${PCT}"
  [ -n "$MODEL" ] && ROW="$ROW ${GRAY}[$MODEL]${RESET}"
  [ -n "$DESC" ] && ROW="$ROW ${GRAY}— ${DESC}${RESET}"

  CONTENT=$(printf '%b' "$ROW")
  jq -n --arg id "$ID" --arg content "$CONTENT" '{id: $id, content: $content}'
done
