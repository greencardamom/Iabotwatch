#!/usr/bin/tcsh

# Push files from a local directory to a remote directory. If "--delete" then it keeps the directories in sync. Otherwise it only uploads new files.
# More info:
#   https://wikitech.wikimedia.org/wiki/Help:Toolforge/Tool_Accounts#Transfer_files
#
# ACTIVE targets (invoked by cron/scripts): peerr, iabotwatch, iabotwatchlogroll, iabotwatchroot.
# The DISABLED block at the bottom holds targets not called by anything currently:
#   arcstat / arcstat-iadetails -> now handled by ~/repos/gh/Arcstat/push.csh
#                                  (and /home/greenc/toolforge/arcstat/iadetails/ no longer exists)
#   awsexp                      -> no caller
#   archivebak                  -> was malformed (unterminated -e quote); local backup, not toolforge
# To re-enable one, uncomment it and re-verify its source + remote path first.

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

if($1 == "peerr") then
  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk /usr/bin/rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/peerr/www/ login.toolforge.org:/data/project/botwikiawk/www/static/peerr/
endif

if($1 == "iabotwatch") then
  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/www/ login.toolforge.org:/data/project/botwikiawk/www/static/dashdaily/
endif

if($1 == "iabotwatchlogroll") then
  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/wwwlogroll/ login.toolforge.org:/data/project/botwikiawk/www/static/iabotwatch/
endif

# Don't delete anything in remote dir
if($1 == "iabotwatchroot") then
  /usr/bin/rsync $v --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/iabotwatch/wwwroot/ login.toolforge.org:/data/project/botwikiawk/www/static/
endif

# ─────────────────────────── DISABLED (not in use) ───────────────────────────
# arcstat + arcstat-iadetails are now handled by ~/repos/gh/Arcstat/push.csh.
#if($1 == "arcstat") then
#  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/arcstat/www/ login.toolforge.org:/data/project/botwikiawk/www/static/dashclassic/
#endif

# NOTE: source /home/greenc/toolforge/arcstat/iadetails/ no longer exists.
#if($1 == "arcstat-iadetails") then
#  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/arcstat/iadetails/ login.toolforge.org:/data/project/botwikiawk/www/static/iadetails/
#endif

# awsexp: no current caller.
#if($1 == "awsexp") then
#  /usr/bin/rsync $v --delete --delay-updates -F --compress --archive --no-owner --no-group --rsh='/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error' --rsync-path='sudo -u tools.botwikiawk rsync' --chmod=Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r /home/greenc/toolforge/awsexp/www/ login.toolforge.org:/data/project/botwikiawk/www/static/awsexp/
#endif

# archivebak: local backup to 192.168.1.16 (NOT toolforge). The recovered original was malformed
# (unterminated -e quote); left disabled. Re-author fully before use.
#if($1 == "archivebak") then
#  /usr/bin/rsync -t -u -W -a --delete -e "/usr/bin/ssh" --rsync-path=/usr/bin/rsync --stats --progress /home/greenc/chico/Archive/ greenc@192.168.1.16:/home/greenc/Backup/Archive/
#endif
