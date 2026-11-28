#!/private/var/herolte/ssh/bin/sh
# A/B of kern.hero_little_idle with the screen off, on the phone itself (no Wi-Fi needed): PAIRS times SECONDS with 0 and
# SECONDS with 1, marking each change with its time in /private/var/tmp/hero-ab.txt (hero-power.txt has the current).
# Usage: hero-ab-reposo.sh [PAIRS] [SECONDS]. The sysctl is left at 0.
export PATH=/private/var/herolte/ssh/bin:/usr/sbin:/usr/bin:/sbin:/bin
PAIRS=${1:-3}
SECONDS_EACH=${2:-180}
OUT=/private/var/tmp/hero-ab.txt
K=kern.hero_little_idle
mark() { echo "$(date +%s) want=$1 state=$(hero-sysctl kern.hero_little_state)" >> "$OUT"; }
echo "$(date +%s) start pairs=$PAIRS seconds=$SECONDS_EACH" >> "$OUT"
i=0
while [ "$i" -lt "$PAIRS" ]; do
  for v in 0 1; do
    hero-sysctl $K $v > /dev/null || { echo "$(date +%s) cannot write $K" >> "$OUT"; exit 1; }
    mark $v
    sleep "$SECONDS_EACH"
    mark $v
  done
  i=$((i + 1))
done
hero-sysctl $K 0 > /dev/null
echo "$(date +%s) end" >> "$OUT"
