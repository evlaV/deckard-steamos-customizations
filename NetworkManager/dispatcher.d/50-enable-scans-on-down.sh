#!/bin/bash

# If we suspend orthe device or disable the interface, make sure when we
# come back up, we are allowed to scan for SSIDs
if [[ "${2:-}" == "down" ]]; then
	echo 0 > /sys/module/cfg80211/parameters/cfg80211_block_scans
fi
