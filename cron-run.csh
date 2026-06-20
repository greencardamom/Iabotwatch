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
    /bin/kill -0 $old_pid >& /dev/null
    
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

# Rescue stranded files from a previous crashed run. MUST run AFTER claiming the
# lock: when two cron instances overlap and both rescue, one moves the files and
# the other's glob matches nothing, which tcsh aborts as "mv: No match". Using
# find -exec also makes the move a no-op (not an error) when there is nothing.
set stranded = `find "$proc_dir" -maxdepth 1 -name "cache.*" | head -n 1`
if ("$stranded" != "") then
    $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [CRON] Rescuing stranded files from processing zone." >> "$monitor_log"
    find "$proc_dir" -maxdepth 1 -name "cache.*" -exec "$MV" {} "$queue_dir"/ \;
endif

# 1. Check if there are actually files in the drop-zone
set has_files = `find "$queue_dir" -maxdepth 1 -name "cache.*" | head -n 1`
if ("$has_files" == "") then
    rm -f "$lockfile"
    exit 0
endif

# 2. BATCHED ATOMIC MOVE: Snatch up to 24 files (6 hours of data) into the lock-zone. To get more let cron-run repeat 
find "$queue_dir" -maxdepth 1 -name "cache.*" | head -n 24 | xargs -I {} mv {} "$proc_dir"/

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
find "$proc_dir" -maxdepth 1 -name "cache.*" -exec "$MV" {} "$done_dir"/ \;
find "$done_dir" -type f -name "cache.*" -mtime +3 -delete

# 6. Generate web tables
"$IABOTWATCH"makehtml.awk

# 7. Release lock
rm -f "$lockfile"
