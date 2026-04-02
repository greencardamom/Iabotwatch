#!/usr/bin/tcsh

# Run stream. It resets every 15 minutes so need to restart. There is a 2-second gap between resets. 

# https://tools-static.wmflabs.org/botwikiawk/iabotwatch.html

# The MIT License (MIT)
#
# Copyright (c) 2020-2024 by User:GreenC (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

source "/home/greenc/toolforge/iabotwatch/set.csh"
setenv AWKPATH .:/home/greenc/BotWikiAwk/lib:/usr/local/share/awk

# Set to 1 to enable logging 
set enable_logging = 0
set monitor_log = "$IABOTWATCH""stream_monitor.log"

mkdir -p "$CHUNKHOME"

while(1 == 1)

   set day1 = `$DATE +"%j"`

   if(! -e "$chunkall") $TOUCH "$chunkall"
   if(-e "$chunkfragment") $RM "$chunkfragment"

   if ($enable_logging == 1) $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [iabotwatch] - Stream CONNECTING..." >> "$monitor_log"

   # 1. Safely check for substance (-s), bypass JSON quotes using @
   if (-s "$last_id_file") then
      $CURL -H @"$last_id_file" -s --speed-limit 1 --speed-time 120 https://stream.wikimedia.org/v2/stream/page-links-change | $GREP --line-buffered -E "^id: |(([/]|[.])archive[.]org[/]|[&]Expires=)" | $SED -u "s/data: //g" | $AWK -b -ilibrary -ijson -f "$IABOTWATCH""iabotwatch.awk" >> "$chunkfragment"
   else
      $CURL -s --speed-limit 1 --speed-time 120 https://stream.wikimedia.org/v2/stream/page-links-change | $GREP --line-buffered -E "^id: |(([/]|[.])archive[.]org[/]|[&]Expires=)" | $SED -u "s/data: //g" | $AWK -b -ilibrary -ijson -f "$IABOTWATCH""iabotwatch.awk" >> "$chunkfragment"
   endif

   if ($enable_logging == 1) $ECHO "`$DATE '+%Y-%m-%d %H:%M:%S'` [iabotwatch] - Stream DISCONNECTED..." >> "$monitor_log"

   # Shuffle files, sort and save most recent 1000
   if(-e "$chunkfragment") $CAT "$chunkfragment" "$chunkall" | $SORT -n | $HEAD -n 1000 > "$chunktemp"
   if(-e "$chunktemp")      $MV "$chunktemp" "$chunkall"
   $CAT "$IABOTWATCH""headerlogroll.html" "$chunkall" "$IABOTWATCH""footer.html" > $output

   # Push $ouput to ~/www/static/iabotwatch on Toolforge
   # $push iabotwatchlogroll

   set day2 = `$DATE +"%j"`
   if($day1 != $day2) then
     if(-e "$IABOTWATCH"isitdead.running.txt) then
       $MV "$IABOTWATCH"isitdead.running.txt "$IABOTWATCH"isitdead.ready.txt
     endif
   endif

   #sleep 2
   sleep 300

end
