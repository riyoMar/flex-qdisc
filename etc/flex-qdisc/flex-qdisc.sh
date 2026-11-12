#!/bin/sh

DEVICE="${1:-phy0-sta0}"                 # interface
IFB="ifb4${DEVICE}"                      # IFB mirror

INTERVAL=${2:-5}                        # seconds

SAFETY=${3:-70}                         # utilization below which the rate decreases

MIN_DL_KBIT=${4:-4000}                  # floor bandwith for ingress(downlink) using Kbits
MIN_UL_KBIT=${5:-4000}                  # floor bandwith for egress(uplink) using Kbits
MAX_DL_KBIT=${9:-30000}                  # ceiling bandwidth for ingress; 0 disables the cap
MAX_UL_KBIT=${10:-30000}                    # ceiling bandwidth for egress; 0 disables the cap
# CAKE bandwidth values and measured rates are in bits/s.
MIN_DL=$((MIN_DL_KBIT * 1000))
MIN_UL=$((MIN_UL_KBIT * 1000))
MAX_DL=$((MAX_DL_KBIT * 1000))
MAX_UL=$((MAX_UL_KBIT * 1000))

if [ "$MAX_DL" -gt 0 ] && [ "$MAX_DL" -lt "$MIN_DL" ]; then
    echo "Maximum download bandwidth is below its minimum; using the minimum as the maximum."
    MAX_DL=$MIN_DL
fi
if [ "$MAX_UL" -gt 0 ] && [ "$MAX_UL" -lt "$MIN_UL" ]; then
    echo "Maximum upload bandwidth is below its minimum; using the minimum as the maximum."
    MAX_UL=$MIN_UL
fi

ALPHA=${6:-10}                          # EMA smoothing factor (0–100)

UP_DELTA=${7:-5}                        # % increase step per interval
DOWN_DELTA=${8:-5}                      # % decrease step per interval
UP_THRESHOLD=$((SAFETY + 20))           # utilization that triggers a rate increase
[ "$UP_THRESHOLD" -gt 95 ] && UP_THRESHOLD=95


rx() { cat /sys/class/net/$DEVICE/statistics/rx_bytes; }
tx() { cat /sys/class/net/$DEVICE/statistics/tx_bytes; }

format_rate() {
    v=$1
    if [ "$v" -ge 1000000 ]; then
        awk "BEGIN{printf \"%.2f Mbit/s\", $v/1000000}"
    elif [ "$v" -ge 1000 ]; then
        awk "BEGIN{printf \"%.2f Kbit/s\", $v/1000}"
    else
        printf "%d bit/s" "$v"
    fi
}

format_limit() {
    if [ "$1" -gt 0 ]; then
        format_rate "$1"
    else
        printf "unlimited"
    fi
}

apply_cake() {
    DL=$1
    UL=$2

    echo
    echo "Applying CAKE:"
    echo " Download: $(format_rate $DL)"
    echo " Upload  : $(format_rate $UL)"

    tc qdisc del dev $DEVICE root 2>/dev/null
    tc qdisc del dev $DEVICE ingress 2>/dev/null
    tc qdisc del dev $IFB root 2>/dev/null

    # Upload (egress)
    tc qdisc add dev $DEVICE root cake bandwidth ${UL}bit \
        besteffort triple-isolate rtt 100ms

    # Ingress redirect
    tc qdisc add dev $DEVICE handle ffff: ingress
    tc filter add dev $DEVICE parent ffff: \
        protocol all u32 match u32 0 0 \
        action mirred egress redirect dev $IFB

    # Download (ingress via IFB)
    tc qdisc add dev $IFB root cake bandwidth ${DL}bit \
        besteffort triple-isolate rtt 100ms
}

# Setup IFB
modprobe ifb
ip link show $IFB >/dev/null 2>&1 || ip link add $IFB type ifb
ip link set $IFB up

AVG_RX=0
AVG_TX=0
APPLIED_DL=$MIN_DL
APPLIED_UL=$MIN_UL

echo "Starting CAKE auto-tuning on $DEVICE (interval=${INTERVAL}s, utilization thresholds=${SAFETY}-${UP_THRESHOLD}%)"
apply_cake "$APPLIED_DL" "$APPLIED_UL"

while true; do
    RX1=$(rx); TX1=$(tx)
    sleep $INTERVAL
    RX2=$(rx); TX2=$(tx)

    RX_BPS=$(( (RX2 - RX1) * 8 / INTERVAL ))
    TX_BPS=$(( (TX2 - TX1) * 8 / INTERVAL ))

    # --- EMA smoothing ---
    if [ "$AVG_RX" -eq 0 ]; then
        AVG_RX=$RX_BPS
        AVG_TX=$TX_BPS
    else
        AVG_RX=$(( (ALPHA * RX_BPS + (100 - ALPHA) * AVG_RX) / 100 ))
        AVG_TX=$(( (ALPHA * TX_BPS + (100 - ALPHA) * AVG_TX) / 100 ))
    fi

    printf "\nMeasured (%ds):\n" "$INTERVAL"
    printf " RX now : %s\n" "$(format_rate $RX_BPS)"
    printf " TX now : %s\n" "$(format_rate $TX_BPS)"
    printf " AVG RX : %s\n" "$(format_rate $AVG_RX)"
    printf " AVG TX : %s\n" "$(format_rate $AVG_TX)"
    printf " CAKE DL: %s (max %s)\n" "$(format_rate "$APPLIED_DL")" "$(format_limit "$MAX_DL")"
    printf " CAKE UL: %s (max %s)\n" "$(format_rate "$APPLIED_UL")" "$(format_limit "$MAX_UL")"

    DL=$APPLIED_DL
    UL=$APPLIED_UL

    # Raise the rate gradually when measured traffic approaches the current cap.
    DL_UP_THRESHOLD=$((APPLIED_DL / 100 * UP_THRESHOLD + APPLIED_DL % 100 * UP_THRESHOLD / 100))
    UL_UP_THRESHOLD=$((APPLIED_UL / 100 * UP_THRESHOLD + APPLIED_UL % 100 * UP_THRESHOLD / 100))
    DL_DOWN_THRESHOLD=$((APPLIED_DL / 100 * SAFETY + APPLIED_DL % 100 * SAFETY / 100))
    UL_DOWN_THRESHOLD=$((APPLIED_UL / 100 * SAFETY + APPLIED_UL % 100 * SAFETY / 100))

    if [ "$AVG_RX" -ge "$DL_UP_THRESHOLD" ]; then
        STEP=$((APPLIED_DL / 100 * UP_DELTA + APPLIED_DL % 100 * UP_DELTA / 100))
        [ "$STEP" -lt 1000 ] && STEP=1000
        DL=$((APPLIED_DL + STEP))
    elif [ "$AVG_RX" -lt "$DL_DOWN_THRESHOLD" ]; then
        STEP=$((APPLIED_DL / 100 * DOWN_DELTA + APPLIED_DL % 100 * DOWN_DELTA / 100))
        [ "$STEP" -lt 1000 ] && STEP=1000
        DL=$((APPLIED_DL - STEP))
    fi

    if [ "$AVG_TX" -ge "$UL_UP_THRESHOLD" ]; then
        STEP=$((APPLIED_UL / 100 * UP_DELTA + APPLIED_UL % 100 * UP_DELTA / 100))
        [ "$STEP" -lt 1000 ] && STEP=1000
        UL=$((APPLIED_UL + STEP))
    elif [ "$AVG_TX" -lt "$UL_DOWN_THRESHOLD" ]; then
        STEP=$((APPLIED_UL / 100 * DOWN_DELTA + APPLIED_UL % 100 * DOWN_DELTA / 100))
        [ "$STEP" -lt 1000 ] && STEP=1000
        UL=$((APPLIED_UL - STEP))
    fi

    [ "$DL" -lt "$MIN_DL" ] && DL=$MIN_DL
    [ "$UL" -lt "$MIN_UL" ] && UL=$MIN_UL
    [ "$MAX_DL" -gt 0 ] && [ "$DL" -gt "$MAX_DL" ] && DL=$MAX_DL
    [ "$MAX_UL" -gt 0 ] && [ "$UL" -gt "$MAX_UL" ] && UL=$MAX_UL

    CHANGE=0
    if [ "$DL" -ne "$APPLIED_DL" ] || [ "$UL" -ne "$APPLIED_UL" ]; then
        CHANGE=1
    fi

    # --- Apply if needed ---
    if [ "$CHANGE" -eq 1 ]; then
        echo
        echo "Significant bandwidth change detected → reapplying CAKE"
        apply_cake "$DL" "$UL"
        APPLIED_DL=$DL
        APPLIED_UL=$UL
    fi
done
