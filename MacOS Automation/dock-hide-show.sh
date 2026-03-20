#!/bin/bash
# Count active displays (1 = internal only).
display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution:/{count++} END{print count+0}')

# Fallback in case system_profiler output format changes.
if [ "$display_count" -eq 0 ]; then
  display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Display Type")
fi

current_hide=$(defaults read com.apple.dock autohide 2>/dev/null || echo "0")

if [ "$display_count" -eq 1 ]; then
  # Hide Dock (auto-hide true) on single screen
  if [ "$current_hide" = "0" ]; then
    osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
  fi
else
  # Show Dock (auto-hide false) with external
  if [ "$current_hide" = "1" ]; then
    osascript -e 'tell application "System Events" to set autohide of dock preferences to false'
  fi
fi
