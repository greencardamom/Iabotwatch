#!/usr/bin/tcsh

# Push files from a local directory to a remote directory. If "--delete" then it keeps the directories in sync. Otherwise it only uploads new files.
# More info:
#   https://wikitech.wikimedia.org/wiki/Help:Toolforge/Tool_Accounts#Transfer_files

if($#argv == 0) then
  echo ""
  echo "push - mirror files to toolforge"
  echo ""
  echo "  ./push <name>"
  echo "  ./push <name> v  -- for verbose progress of files uploaded and deleted"
  echo ""
endif

if($2 == "v") then
  set v="--progress"
else
  set v=""
endif

if($1 == "iabotwatch") then
  rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/www/ login.toolforge.org:/data/project/botwikiawk/www/static/dashdaily/
endif

if($1 == "iabotwatchlogroll") then
  rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/wwwlogroll/ login.toolforge.org:/data/project/botwikiawk/www/static/iabotwatch/
endif

# Don't delete anything in remote dir
if($1 == "iabotwatchroot") then
  rsync $v --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/wwwroot/ login.toolforge.org:/data/project/botwikiawk/www/static/
endif

