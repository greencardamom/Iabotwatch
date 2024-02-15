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
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

source "/home/greenc/toolforge/iabotwatch/set.csh"
setenv AWKPATH .:/home/greenc/BotWikiAwk/lib:/usr/local/share/awk

set output = "/home/greenc/toolforge/iabotwatch/wwwlogroll/iabotwatch.html"
set push = "/home/greenc/toolforge/scripts/push"
set chunkfragment = "$IABOTWATCH"chunkfragment.html
set chunkall = "$IABOTWATCH"chunkall.html
set chunktemp = "$IABOTWATCH"chunktemp.html

while(1 == 1)

   set day1 = `$DATE +"%j"`

   # EventStream exits every 15 minutes 

   if(! -e "$chunkall") $TOUCH "$chunkall"
   if(-e "$chunkfragment") $RM "$chunkfragment"

   # $CURL -s https://stream.wikimedia.org/v2/stream/page-links-change | $GREP "InternetArchiveBot" | $GREP -iE "([/]|[.])archive[.]org" | $SED "s/data: //g" | $AWK -b -ilibrary -ijson -f "$IABOTWATCH""iabotwatch.awk" >> "$chunkfragment"
   $CURL -s https://stream.wikimedia.org/v2/stream/page-links-change | $GREP -E "(([/]|[.])archive[.]org[/]|[&]Expires=)" | $SED "s/data: //g" | $AWK -b -ilibrary -ijson -f "$IABOTWATCH""iabotwatch.awk" >> "$chunkfragment"

   # Shuffle files, sort and save most recent 1000

   if(-e "$chunkfragment") $CAT "$chunkfragment" "$chunkall" | $SORT -rn | $HEAD -n 1000 > "$chunktemp"
   if(-e "$chunktemp")     $MV "$chunktemp" "$chunkall"
   $CAT "$IABOTWATCH""headerlogroll.html" "$chunkall" "$IABOTWATCH""footer.html" > $output

   # Push $ouput to ~/www/static/iabotwatch on Toolforge
   $push iabotwatchlogroll

   set day2 = `$DATE +"%j"`
   if($day1 != $day2) then
     if(-e "$IABOTWATCH"isitdead.running.txt) then
       $MV "$IABOTWATCH"isitdead.running.txt "$IABOTWATCH"isitdead.ready.txt
     endif
   endif

end


