# File with functions to catch the current ingame day and time
# Checking .env init
if [ -z "$VSSDIR" ]
then
   # Basic env init
   CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
   source "$CWD/../.env"
else
   CWD="$VSSDIR/lib"
fi

exec 2>>"$VSSDIR/crash.log"

# Test by-pass
if [ "${DEBUGMODE:-0}" -eq 1 ];
then
   source "$CWD/../.env.test"
fi

# DOC
# New day log pattern when player sleep (example, ONLY OCCUR WHEN PLAYERS SLEEP !) : 
# 10/01/2026 09:37:13: Time 692882,977320414, day:384    nextm:693270,000010729  skipspeed:32,2518908595666
# 10/01/2026 12:02:45: Time 695051,759307146, day:385    nextm:695070,000010729  skipspeed:1,52005863189697
# 10/01/2026 12:26:29: Time 696484,419452202, day:386    nextm:696870,000010729  skipspeed:32,1317132106051
# 10/01/2026 12:50:45: Time 698306,85944334, day:387    nextm:698670,000010729  skipspeed:30,2617139490321
# 10/01/2026 17:04:48: Time 706824,679633744, day:392    nextm:707670,000010729  skipspeed:70,4433647487313
# 10/01/2026 17:18:37: Time 708478,319691539, day:393    nextm:709470,000010729  skipspeed:82,6400265991688
# 10/01/2026 21:40:34: Time 725606,578614201, day:402    nextm:725670,000010729  skipspeed:5,28511637728661
# 10/03/2026 13:45:33: Time 761164,659499492, day:422    nextm:761670,000010729  skipspeed:42,111709269695
# diff between two nextm : 1800 (time elapsed during 1 ingame day)
# 422 - 392 = 30 days * 1800 = 54k
# Time 706824 vs Time 761164, diff = 54340 ~ Good
# nextm 707670 vs nextm 761670, diff = 54000 -> Good
# Strategy : 
# - Check occurences of Connections[[:space:]]+0([[:space:]]|$) to pause time increment since last "Time/Day" log in today's logs
# - Check occurences of Connections[[:space:]]+[1-9].[0-9]?([[:space:]]|$) to unpause time increment since last "Time/Day" log in today's logs
refresh_ingame_time_values_cache() {
    SNAPSHOTCACHEFILE="$INGAMETIMESNAPSHOTFILE.cache"
    if [ -f "$SNAPSHOTCACHEFILE" ]; then
        SLEEPSNAPSHOT=$(cat "$SNAPSHOTCACHEFILE" 2>/dev/null || echo "0")
    else
        SLEEPSNAPSHOT=$(cat "$INGAMETIMESNAPSHOTFILE" 2>/dev/null || echo "0")
    fi

    if [ -z "$SLEEPSNAPSHOT" ] || [ "$SLEEPSNAPSHOT" = "0" ]; then
    echo "[INGAMETIME] No ingame time snapshot found, using default values. You need to sleep ingame or create a manual snapshot following this pattern \"10/03/2026 13:45:33: Time 761164,659499492, day:422    nextm:761670,000010729  skipspeed:42,111709269695\" in $INGAMETIMESNAPSHOTFILE" >&2
    exit 1
    fi

    if [[ "$SLEEPSNAPSHOT" =~ ^([0-9]+/[0-9]{2}/[0-9]{4})[[:space:]]+([0-9]{2}:[0-9]{2}:[0-9]{2}):[[:space:]]+Time[[:space:]]+([0-9]+),([0-9]+),[[:space:]]+day:([0-9]+)[[:space:]]+nextm:([0-9]+),([0-9]+)[[:space:]]+skipspeed:([0-9]+),([0-9]+)$ ]]; then
        SNAPSHOTDATE=$(date -d "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}" +%s)
        SNAPSHOTTIME="${BASH_REMATCH[3]},${BASH_REMATCH[4]}"
        SNAPSHOTDAY="${BASH_REMATCH[5]}"
        SNAPSHOTNEXTM="${BASH_REMATCH[6]},${BASH_REMATCH[7]}"
        SNAPSHOTSKIPSPEED="${BASH_REMATCH[8]},${BASH_REMATCH[9]}"
        LOGFILENAMETOSEARCH="${BASH_REMATCH[1]:6:4}-${BASH_REMATCH[1]:3:2}-${BASH_REMATCH[1]:0:2}"
    else
        echo "[INGAMETIME] Invalid ingame time snapshot format in $INGAMETIMESNAPSHOTFILE. You need to sleep ingame or create a manual snapshot following this pattern \"10/03/2026 13:45:33: Time 761164,659499492, day:422    nextm:761670,000010729  skipspeed:42,111709269695\"" >&2
        exit 1
    fi
    
    ACTIVITYELAPSED=$(
    for file in "$VSSDIR"/valheim-logs.d/*.stdout.log; do
        [ "$(basename "$file" .stdout.log)" \< "$LOGFILENAMETOSEARCH" ] && continue
        grep 'Connections [0-9]' "$file"
    done |
    while read date time _ connections rest; do
        [[ "$date" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]] || continue
        timestamp=$(date -d "$date ${time%:}" +%s)
        [ "$timestamp" -gt "$SNAPSHOTDATE" ] && echo "$timestamp $connections"
    done
    )

    ELAPSED=$(echo "$ACTIVITYELAPSED" |
    awk 'NR>1 && prev>0 {sum += $1-last} {last=$1; prev=$2}
        END {if(prev>0) sum += systime()-last; print sum+0}')

    # Very important: If calculation get messy, it probably come from here:
    CURRENTTIMEINSECONDS=$(awk -v t="$SNAPSHOTTIME" -v e="$ELAPSED" 'BEGIN {print t+e}')

    # Considering a "new day" start at 0.15 * 24 = 3:36 (correspond to nextm value in snapshot, 761670,000010729, which is 761670 seconds = 423,15 days -> 3:36)
    # We dont care for our attemp to get precise
    SECONDSPERINGAMEDAY=1800
    INGAMEDAY=$(awk -v t="$CURRENTTIMEINSECONDS" -v d="$SECONDSPERINGAMEDAY" \
        'BEGIN {print int(t/d)}')
    MODULOINGAMETIME=$(awk -v t="$CURRENTTIMEINSECONDS" -v d="$SECONDSPERINGAMEDAY" \
        'BEGIN {print t%d}')
    SECONDSPERINGAMEHOUR=$(awk -v d="$SECONDSPERINGAMEDAY" \
        'BEGIN {print d/24}')
    INGAMEHOUR=$(awk -v t="$MODULOINGAMETIME" -v h="$SECONDSPERINGAMEHOUR" \
        'BEGIN {print int(t/h)}')
    INGAMEMINUTE=$(awk -v t="$MODULOINGAMETIME" -v h="$SECONDSPERINGAMEHOUR" -v hour="$INGAMEHOUR" \
        'BEGIN {print int((t - hour*h) * 60 / h)}')

    INGAMETIME=$(printf "%02d:%02d" "$INGAMEHOUR" "$INGAMEMINUTE")

    PREDICTEDNEXTM=$(awk -v n="$INGAMEDAY" -v d="$SECONDSPERINGAMEDAY" \
        'BEGIN {print int(n*d) + d}')

    # Reminder ! 10/03/2026 13:45:33 for 3rd of October !
    NOW=$(date '+%m/%d/%Y %H:%M:%S')

    # Test by-pass
    if [ "${DEBUGMODE:-0}" -eq 1 ];
    then
        echo "Snapshot Date : $SNAPSHOTDATE ($(date -d @$SNAPSHOTDATE))"
        echo "Snapshot Time : $SNAPSHOTTIME"
        echo "Snap Logfiles>: $LOGFILENAMETOSEARCH"
        echo "Elapsed       : $ELAPSED s"
        echo "Current Time  : $CURRENTTIMEINSECONDS s"
        echo "Day           : $INGAMEDAY"
        echo "Time          : $INGAMETIME"
        echo "NewSnapshot   : $NOW: Time $CURRENTTIMEINSECONDS,000000000, day:$INGAMEDAY, nextm:$PREDICTEDNEXTM"
    fi

    # Building cache file
    # Pattern reminder : 10/03/2026 13:45:33: Time 761164,659499492, day:422    nextm:761670,000010729  skipspeed:42,111709269695
    printf '%s: Time %s,000000000, day:%s    nextm:%s  skipspeed:1,000000000000\n' \
    "$NOW" "$CURRENTTIMEINSECONDS" "$INGAMEDAY" "$PREDICTEDNEXTM" > "$SNAPSHOTCACHEFILE"
}

get_ingame_time_with_emoji() {
    local seconds=$((10#${INGAMETIME:0:2} * 3600 + 10#${INGAMETIME:3:2} * 60))

    if [ "$seconds" -ge $((3*3600+36*60)) ] && [ "$seconds" -lt $((20*3600+24*60)) ]; then
        echo "☀️ $INGAMETIME"
    else
        echo "🌙 $INGAMETIME"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    refresh_ingame_time_values_cache
fi
