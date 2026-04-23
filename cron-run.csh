#!/usr/bin/tcsh
source "/home/greenc/toolforge/iabotwatch/set.csh"
setenv AWKPATH .:/home/greenc/BotWikiAwk/lib:/usr/local/share/awk

set cache_dir = "$IABOTWATCH""cache"
set queue_dir = "$cache_dir/queue"
set proc_dir  = "$cache_dir/processing"
set done_dir  = "$cache_dir/done"

# Ensure directories exist
mkdir -p "$cache_dir"
mkdir -p "$queue_dir"
mkdir -p "$proc_dir"
mkdir -p "$done_dir"

# 0. Prevent overlapping executions and handle stale locks
set lockfile = "$IABOTWATCH""cron.lock"
if (-e "$lockfile") then
    set old_pid = `cat "$lockfile"`
    
    # kill -0 returns 0 if alive, non-zero if dead
    kill -0 $old_pid >& /dev/null
    
    if ($status == 0) then
        # Process is still running; exit without doing anything
        exit 0
    else
        # Process is dead; stale lock detected. Log it and remove the lock.
        $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [CRON] Stale lock detected for dead PID $old_pid. Recovering." >> "$monitor_log"
        rm -f "$lockfile"
    endif
endif
# Claim the lock with the current script's PID
echo $$ > "$lockfile"

# 1. Check if there are actually files in the drop-zone
set has_files = `find "$queue_dir" -maxdepth 1 -name "cache.*" | head -n 1`
if ("$has_files" == "") exit 0

# 2. ATOMIC MOVE: Snatch all current files out of the drop-zone into the lock-zone
$MV "$queue_dir"/cache.* "$proc_dir"/

# 3. Run the standalone AWK script ONLY on the locked files
"$IABOTWATCH"transform.awk "$proc_dir"/cache.*
set awk_status = $status

# 3b. Halt and preserve files if the AWK script crashed
if ($awk_status != 0) then
    $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [CRON] transform.awk failed with status $awk_status. Halting." >> "$monitor_log"
    rm -f "$lockfile"
    exit 1
endif

# 4. HTML Log Rolling
set frag = "$IABOTWATCH""cache/chunkfragment.html"
set all  = "$IABOTWATCH""cache/chunkall.html"
set temp = "$IABOTWATCH""cache/chunktemp.html"

if (-e "$frag") then
    $CAT "$frag" "$all" | $SORT -n | $HEAD -n 1000 > "$temp"
    $MV "$temp" "$all"
endif

$CAT "$IABOTWATCH""headerlogroll.html" "$all" "$IABOTWATCH""footer.html" > "$IABOTWATCH""wwwlogroll/iabotwatch.html"

# 5. Archive processed files instead of destroying them (Keep for 3 days)
$MV "$proc_dir"/cache.* "$done_dir"/
find "$done_dir" -type f -name "cache.*" -mtime +3 -delete

# 6. Generate web tables
"$IABOTWATCH"makehtml.awk

# 7. Release lock
rm -f "$lockfile"
