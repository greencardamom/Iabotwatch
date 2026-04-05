Iabotwatch
===========
Iabotwatch creates tables showing the number of edits by IABot, GreenC bot, users etc.. based on the input of MediaWiki EventStream API 

The product is "InternetArchiveBot Dashboard" and the program that generates it is "Iabotwatch".

How it works
==========

Architecture is a Producer/Consumer aka ETL model (Extract, Transform, Load)

It watches WMF EventsStream API for events of interest and charts them.

* **`iabw-stream.csh`** - Runs continuously. Every 15 minutes the EventsStream API stops and restarts.
  * Extracts JSON records of interest into the file `cache/cache.live`.
  * During cycles, moves existing `cache.live` into `cache/queue/cache.<timestamp>`.
* **`extract.awk`** - Used by `iabw-stream.csh` - it extracts the JSON records of interest into `cache/cache.live`.
* **`transform.awk`** - Runs via `cron-run.csh`. It processes ("transforms") the JSON files in `cache/queue/cache.<timestamp>` into the native db format of iabotwatch stored in `/db/YYYY`.
* **`makehtml.awk`** - Runs via `cron-run.csh`. It creates the HTML report in `~/html` based on the data in `~/db` (that was created by `transform.awk`)
* **`cron-run.csh`** - Runs from cron, wrapper for `transform.awk` and `makehtml.awk`, it also cycles files, and pushes the final report to the web host, Toolforge.
* **`moniabw.awk`** - Healthcheck script restarts `iabw-stream.csh` if not running.

```text
[ Wikimedia EventStreams ]
          │
          ▼  (Continuous Connection)
  1. iabw-stream.csh + extract.awk ───────► Writes to: cache/cache.live
          │
          ▼  (~15 Min Cycle Drops)
     Atomic Move ────────────────────► Move cache/cache.live to cache/queue/cache.<timestamp>
          │
          ▼  (Hourly Cron)
  2. cron-run.csh + transform.awk ───► Writes to: /db/YYYY/
          │
          ▼  (Periodic Cron)
  3. makehtml.awk ───────────────────► Writes to: /html/
          │
          ▼  (Push to Toolforge)
  4. https://... final report
  
```

* **The Producer** (`iabw-stream.csh` & `extract.awk`): Only cares about catching the data. It has no idea the database even exists.
* **The Consumer** (`transform.awk`): Only cares about processing files in the queue. It doesn't care where the stream comes from or if the WMF connection goes down.

For a schema on how the `~/www/db` files are structured, see `~/www/db/Documentation.txt`.

## Dependencies

* GNU awk 4.1+
* tcsh
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) library

## Setup 

* Install `tcsh`, e.g.:
  ```bash
  sudo apt-get install tcsh
  ```

* Install BotWikiAwk library:
  ```bash
  cd ~ 
  git clone [https://github.com/greencardamom/BotWikiAwk](https://github.com/greencardamom/BotWikiAwk)
  export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
  export PATH=$PATH:/home/user/BotWikiAwk/bin
  cd ~/BotWikiAwk
  ./setup.sh
  ```
  *(Read `SETUP` for further instructions, e.g., setting up email).*

* All of the files are assumed to have some hard-coded paths. Edit each and check for changes specific to your system.
* This distribution is configured to use Toolforge as the web host. It uses `rsync` to mirror the local `~/www` directories to Toolforge. The script `push.csh` does the mirroring. Edit this script to adjust paths and logins. Or use a different web hosting method. It assumes you have passwordless ssh setup.
* This distribution does not include the data and HTML files in `~/www/db/*` and `~/www/*` respectively. They can be downloaded from Toolforge, or contact the sysadmins there for backups.

## Credits

by User:GreenC (en.wikipedia.org)  
MIT License Copyright 2026

Iabotwatch uses the [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) framework of tools and libraries for building and running bots on Wikipedia.
