#!/usr/bin/tcsh
source "/home/greenc/toolforge/iabotwatch/set.csh"
setenv AWKPATH .:/home/greenc/BotWikiAwk/lib:/usr/local/share/awk

set cache_dir = "$IABOTWATCH/cache"
mkdir -p "$cache_dir/queue"

while(1 == 1)
   $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [iabotwatch] - Stream CONNECTING..." >> "$monitor_log"

   $CURL -s --connect-timeout 15 --speed-limit 1 --speed-time 120 https://stream.wikimedia.org/v2/stream/page-links-change | $GREP --line-buffered -E "^id: |(([/]|[.])archive[.]org[/]|[&]Expires=)" | $SED -u "s/data: //g" | $AWK -b -ilibrary -ijson -f "$IABOTWATCH""extract.awk" >> "$cache_dir/cache.active"

   $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [iabotwatch] - Stream DISCONNECTED..." >> "$monitor_log"

   if (-e "$cache_dir/cache.active") then
       $MV "$cache_dir/cache.active" "$cache_dir/queue/cache.`$DATE +%s`"
   endif

   $SLEEP 2
end
