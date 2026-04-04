#!/usr/bin/tcsh
source "/home/greenc/toolforge/iabotwatch/set.csh"
setenv AWKPATH .:/home/greenc/BotWikiAwk/lib:/usr/local/share/awk

set cache_dir = "$IABOTWATCH""cache"
set queue_dir = "$cache_dir/queue"
set proc_dir  = "$cache_dir/processing"

# Ensure directories exists
mkdir -p "$cache_dir"
mkdir -p "$queue_dir"
mkdir -p "$proc_dir"

# 1. Check if there are actually files in the drop-zone
set has_files = `find "$queue_dir" -maxdepth 1 -name "cache.*" | head -n 1`
if ("$has_files" == "") exit 0

# 2. ATOMIC MOVE: Snatch all current files out of the drop-zone into the lock-zone
$MV "$queue_dir"/cache.* "$proc_dir"/

# 3. Run the standalone AWK script ONLY on the locked files
"$IABOTWATCH"transform.awk "$proc_dir"/cache.*

# 4. HTML Log Rolling
set frag = "$IABOTWATCH""cache/chunkfragment.html"
set all  = "$IABOTWATCH""cache/chunkall.html"
set temp = "$IABOTWATCH""cache/chunktemp.html"

if (-e "$frag") then
    $CAT "$frag" "$all" | $SORT -n | $HEAD -n 1000 > "$temp"
    $MV "$temp" "$all"
endif

$CAT "$IABOTWATCH""headerlogroll.html" "$all" "$IABOTWATCH""footer.html" > "$IABOTWATCH""wwwlogroll/iabotwatch.html"

# 5. Destroy ONLY the files we actually processed
$RM -f "$proc_dir"/cache.*
