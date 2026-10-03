#!/bin/bash
# Deep suspend hot-unplugs CPUs 1-7, so every IRQ migrates to CPU0
# (kernel/irq/cpuhotplug.c migrate_one_irq). On resume only *managed* IRQs are
# moved back (irq_restore_affinity_of_irq). Non-managed MSIs such as ath12k's 16
# vectors stay on CPU0 until reboot, and so does all of their NET_RX work.
#
# pre:  record each matching IRQ's effective CPU in $STATE.
# post: pin every IRQ whose effective CPU changed back to its pre-suspend CPU.
#       This reproduces the boot-time layout exactly, but smp_affinity becomes
#       that single CPU.

# Extended regex on the chip/hwirq/name column of /proc/interrupts.
# Default: every MSI behind the GIC ITS (on this platform: ath12k).
MATCH='ITS-PCI-MSI'
STATE=/run/irq-respread.state

log() { echo "irq-respread: $*"; }

# Print "irq<TAB>effective<TAB>name" for matching IRQs.
snapshot() {
	local ncpu
	ncpu=$(head -1 "/proc/interrupts" | wc -w)
	awk -v n="$ncpu" -v re="$MATCH" 'NR > 1 && $1 ~ /^[0-9]+:$/ {
		irq = $1; sub(":", "", irq)
		name = ""; for (i = n + 2; i <= NF; i++) name = name (name ? " " : "") $i
		if (name ~ re) print irq "\t" name
	}' "/proc/interrupts" | while IFS=$'\t' read -r irq name; do
		eff=$(cat "/proc/irq/$irq/effective_affinity_list" 2>/dev/null) || continue
		printf '%s\t%s\t%s\n' "$irq" "$eff" "$name"
	done
}

case ${1:-} in
pre)
	snapshot > "$STATE"
	log "saved $(wc -l < "$STATE") IRQs matching '$MATCH'"
	;;
post)
	[[ -s $STATE ]] || { log "no saved state, nothing to do"; exit 0; }
	moved=0 failed=0
	while IFS=$'\t' read -r irq eff name; do
		f=/proc/irq/$irq/smp_affinity_list
		[[ -w $f ]] || continue                 # IRQ freed while suspended
		now=$(cat "/proc/irq/$irq/effective_affinity_list" 2>/dev/null)
		[[ $now == "$eff" ]] && continue
		if echo "$eff" > "$f" 2>/dev/null; then
			moved=$((moved + 1))
			log "IRQ $irq ($name): eff $now -> $(cat "/proc/irq/$irq/effective_affinity_list")"
		else
			failed=$((failed + 1))
			log "IRQ $irq ($name): failed to pin to CPU $eff"
		fi
	done < "$STATE"
	log "moved $moved IRQs, $failed failed"
	;;
esac
exit 0
