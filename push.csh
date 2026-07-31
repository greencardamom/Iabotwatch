#!/usr/bin/tcsh

# Push files from a local directory to a remote directory on Toolforge.
# "--delete" keeps the dirs in sync; otherwise only new files are uploaded.
# More info:
#   https://wikitech.wikimedia.org/wiki/Help:Toolforge/Tool_Accounts#Transfer_files
#
# RESILIENCE: login.toolforge.org is a load-balanced bastion; a momentary SSH-transport
# blip shows up as rsync exit 255 "connection unexpectedly closed (0 bytes received)".
# We retry with linear backoff and ONLY fail if every attempt fails. Each attempt's stderr
# is captured to a temp file (not emitted), so a single transient blip is silent and the
# upload still lands; a genuine outage surfaces the real error + a summary and exits 1.
# (push is called from makehtml.awk via sys2var(), which captures STDOUT, so anything we
# want visible in cron mail must go to STDERR.) ConnectTimeout bounds a hung connect.

if ($#argv == 0) then
  echo ""
  echo "push - mirror files to toolforge"
  echo ""
  echo "  ./push <name>"
  echo "  ./push <name> v  -- for verbose progress of files uploaded and deleted"
  echo ""
  exit 1
endif

set v = ""
if ($#argv >= 2) then
  if ("$2" == "v") set v = "--progress"
endif

# Common rsync transport/options, shared by every target.
set rsh   = "/usr/bin/ssh -S none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -E /dev/null -o LogLevel=error -o ConnectTimeout=15"
set rpath = "sudo -u tools.botwikiawk rsync"
set chmod = "Dug=rwx,Dg+s,Do=rx,Fug=rw,Fo=r"

# Per-target: source dir, remote dest, and whether to mirror-delete.
set src = ""
set dst = ""
set del = ""

if ($1 == "iabotwatch") then
  set del = "--delete"
  set src = "/home/greenc/toolforge/iabotwatch/www/"
  set dst = "login.toolforge.org:/data/project/botwikiawk/www/static/dashdaily/"
endif
if ($1 == "iabotwatchlogroll") then
  set del = "--delete"
  set src = "/home/greenc/toolforge/iabotwatch/wwwlogroll/"
  set dst = "login.toolforge.org:/data/project/botwikiawk/www/static/iabotwatch/"
endif
if ($1 == "iabotwatchroot") then
  # Don't delete anything in remote dir
  set del = ""
  set src = "/home/greenc/toolforge/iabotwatch/wwwroot/"
  set dst = "login.toolforge.org:/data/project/botwikiawk/www/static/"
endif

if ("$src" == "") then
  echo "push.csh: unknown target '$1' - nothing to do." >> /dev/stderr
  exit 0
endif

# rsync with retry + linear backoff (10s, 20s). Capture each attempt's stderr so transient
# failures are silent; only a total failure prints the real reason to cron mail.
set err = "/tmp/push.$$.err"
set max = 3
set n = 1
while ($n <= $max)
  ( rsync $v $del --delay-updates -F --compress --archive --no-owner --no-group --rsh="$rsh" --rsync-path="$rpath" --chmod="$chmod" "$src" "$dst" > /dev/null ) >& "$err"
  if ($status == 0) then
    rm -f "$err"
    exit 0
  endif
  if ($n < $max) then
    @ backoff = $n * 10
    sleep $backoff
  endif
  @ n++
end

# Every attempt failed - surface the real rsync error + a summary, then fail loudly.
echo "push.csh: rsync of '$1' to $dst FAILED after $max attempts (transient Toolforge SSH/transport?):" >> /dev/stderr
cat "$err" >> /dev/stderr
rm -f "$err"
exit 1
