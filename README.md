Iabotwatch
===========
Iabotwatch creates tables showing the number of edits by IABot, GreenC bot, users etc.. based on the input of MediaWiki EventStream API 

* https://tools-static.wmflabs.org/botwikiawk/dashdaily.html

The product is "InternetArchiveBot Dashboard" and the program that generates it is "Iabotwatch".

How it works
==========

* moniabw.awk runs from cron every 5 minutes to check that iabotwatch.csh is running and if not starts iabotwatch.csh

* iabotwatch.csh runs curl pulling an EventStream (ES) and pipes the stream through iabotwatch.awk
** ES halts on the MediaWiki side about every 15 minutes, so the script has an endless loop that restarts the curl command
** During the restarts, the script shuffles data files around, makes new directories as months and years roll over, etc..

* iabotwatch.awk takes as input a single JSON record from the ES. 
** It parses the JSON and records the statistics in the ~/www/db/<year>/<day>.txt file
** It records other things like URLs with an archive.org/details etc.. whatever we want to track

* makehtml.awk runs about once an hour. 
** It rebuilds the HTML files in ~/www/<year> by parsing the data files in  ~/www/db/<year>

For an understanding how the ~/www/db files are structured, see ~/www/db/Documentation.txt

Dependencies
====
* GNU awk 4.1+
* tcsh
* BotWikiAwk library

Setup 
=====
* Install tcsh eg

        sudo apt-get install tcsh

* Install BotWikiAwk library

        cd ~ 
        git clone 'https://github.com/greencardamom/BotWikiAwk'
        export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
        export PATH=$PATH:/home/user/BotWikiAwk/bin
        cd ~/BotWikiAwk
        ./setup.sh
        read SETUP for further instructions eg. setting up email

* All of the files are assumed to have some hard coded paths. Edit each and check for changes specific to your system.

* This distribution is configured to use Toolforge as the web host. It uses rsync to mirror the local ~/www directories to Toolforge. The script "push.csh" does the mirroring. Edit this script to adjust paths and logins. Or use a different web hosting method. It assumes you have passwordless ssh setup.

* This distribtion does not include the data and html files in ~/www/db/* and ~/www/* respectively. They can be downloaded from Toolforge or contact the sysadmins there for backups.

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024

Iabotwatch uses the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk
