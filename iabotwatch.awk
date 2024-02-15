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

BEGIN {

  IGNORECASE = 1

  G["toolforge"] = "/home/greenc/toolforge/"
  G["home"] = G["toolforge"] "iabotwatch/"
  G["dbdir"] = G["home"] "www/db/"
  G["awsexp"] = G["toolforge"] "awsexp/"

  while ((getline line < "/dev/stdin") > 0) {

    json = strip(line)
    delete URLZ1  # for archive URL added by IABot
    delete URLZ2  # for archive URL added by users
    delete URLZ3  # for archive URL added by other bots
    delete URLZ4  # for isitdead tracking
    delete URLB1  # for books added by IABot
    delete URLB2  # for books added by other
    delete URLB3  # for sim_ books added by IABot

    logfile = getlogfile()

    # print json >> "rev4.json"

    if( query_json(json, jsona) >= 0) {
      # awkenough_dump(jsona, "jsona")
      if(int(jsona["added_links","0"]) > 0) {
        nadded = int(jsona["added_links","0"])
        uri = jsona["meta", "uri"]
        wpdomain = jsona["meta", "domain"]
        wpsite  = jsona["database"]                       # "enwiki", "frwiki", "enwiktionary", etc..
        pageid  = jsona["page_id"]
        revid   = jsona["rev_id"]
        pagens  = jsona["page_namespace"]
        wpname  = gsubi("_", " ", jsona["page_title"])
        wpuser  = jsona["performer","user_text"]
        wpisbot = jsona["performer","user_is_bot"]

        # Skip all page namespaces except main (0) and File: (6)
        if(pagens !~ /^(0|6)$/) 
          continue

        #if(wpsite == "arzwiki") {
        #  print json >> "arzwiki.json"
        #  close("arzwiki.json")
        #}

        #{"$schema":"/mediawiki/page/links-change/1.0.0","meta":{"uri":"https://commons.wikimedia.org/wiki/File:(untitled)_The_Crayon_(1860-06-01),_page_181_(IA_jstor-25528077).pdf","request_id":"74db8d82-25ec-4c93-b0aa-5d9069f502ff","id":"fb1d7a63-835c-43f7-8981-9535d9a38446","dt":"2021-03-22T06:15:45Z","domain":"commons.wikimedia.org","stream":"mediawiki.page-links-change","topic":"eqiad.mediawiki.page-links-change","partition":0,"offset":1087370918},"database":"commonswiki","page_id":102113090,"page_title":"File:(untitled)_The_Crayon_(1860-06-01),_page_181_(IA_jstor-25528077).pdf","page_namespace":6,"page_is_redirect":false,"rev_id":545072089,"performer":{"user_text":"Fæ","user_groups":["accountcreator","filemover","image-reviewer","ipblock-exempt","rollbacker","templateeditor","*","user","autoconfirmed"],"user_is_bot":false,"user_id":1086557,"user_registration_dt":"2010-03-29T16:40:39Z","user_edit_count":10002707},"added_links":[{"link":"/wiki/Commons:Publication","external":false},{"link":"https://creativecommons.org/publicdomain/mark/1.0/deed.en","external":true},{"link":"http://www.jstor.org/stable/10.2307/25528077","external":true},{"link":"https://archive.org/metadata/jstor-25528077","external":true},{"link":"https://archive.org/download/jstor-25528077/25528077.pdf","external":true}]}
        # Skip if Commons and uploading an individual page of a book 
        if(wpsite == "commonswiki" && uri ~ "[_]page[_]")
          continue

        # Edge case site name transforms. See also driver.awk for noisbn
        if(wpsite == "zh_yuewiki") wpsite = "zh-yuewiki"
        if(wpsite == "be_x_oldwiki") wpsite = "be-taraskwiki"

        # Convert jsona["meta","dt"] to US/Pacific time
        #   https://unix.stackexchange.com/questions/48101/how-can-i-have-date-output-the-time-from-a-different-timezone
        datetime = sys2var("TZ=\":US/Pacific\" /bin/date -d \"" jsona["meta","dt"] "\" \"+%Y-%m-%dT%H:%M:%S\"")

        # By default, either user or userbot
        if(int(wpisbot) == 1)
          perp = "userbot"
        else
          perp = "user"

        for(j = 1; j <= nadded; j++) {
          if(jsona["added_links",j,"external"] == 1) {
            url = urldecodeawk(urldecodeawk(jsona["added_links",j,"link"]))

            # archives
            if(url ~ "https://web.archive.org/web/") {

              if(wpuser ~ "InternetArchiveBot") {
                URLZ1[url]++
                URLZ4[url]++  # isitdead - keep sep for now 
              }
              else if(perp ~ "userbot")
                URLZ3[url]++
              else
                URLZ2[url]++

            }

            # books
            if(url ~ "/archive.org/details/") {
              if(match(url, "details[/][^$/]+[^$/]", d) > 0) {
                key = gsubi("(details[/]|[/]page[/][^$/]+[^$/])","",d[0])
                if(json ~ "InternetArchiveBot") {
                  # ++ is causing double-counting due to double URLs within a citation
                  # URLZ1[gsubi("(details[/]|[/]page[/][^$/]+[^$/])","",d[0])]++
                  # = 1 will avoid double-counting but misses when ID used more than 1 citation per article

                  if(wpsite == "arzwiki" && (u == "periodictableits0000scer" || u == "naturesbuildingb0000emsl" || u == "elementsvisualex0000gray") ) {
                      donothing++
                  }
                  else {
                    if(url ~ "/details/sim_")
                      URLB3[key] = 1
                    else
                      URLB1[key] = 1
                  }
                }
                else 
                  URLB2[key] = 1
              }
            }

            # Expires= URL (see awsexp.awk)
            if(url ~ /[&]Expires=/) {
              if(wpsite == "enwiki") {
                print wpname " ---- " url " ---- " sys2var("/usr/bin/date \"+%Y%m%dT%H:%M:%S\"") >> G["awsexp"] "dropoff.txt"
                close(G["awsexp"] "dropoff.txt")
              }
            }
          }

        }

        # Get edit comment and edit tags from API:Revisions
        commandurl = "https://" wpdomain "/w/api.php?action=query&prop=revisions&revids=" revid "&rvprop=comment|tags|timestamp&format=json"
        jsonrev = http2var(commandurl)
        if( query_json(jsonrev, jsonreva) >= 0) { 

          comment   = jsonreva["query","pages",pageid,"revisions","1","comment"]
          timestamp = jsonreva["query","pages",pageid,"revisions","1","timestamp"]

          # Workaround for Streams bug https://phabricator.wikimedia.org/T303907
          # If reported diff is greater than 2 days from now ignore it.
          epochnow = sys2var("/usr/bin/date -u +\"%s\"")
          epochdiff = sys2var("/usr/bin/date -u -d \"" timestamp "\" +\"%s\"")
          epochlength = int(epochnow) - int(epochdiff)
          if(int(epochlength) < 1) continue
          epochdays = int((((int(epochlength) / 60) / 60) / 24)) # number of days between now and when diff was made
          if(int(epochdays) > 2) {
            #print wpsite " ---- " sys2var(Exe["date"] " +\"%Y%m%d\"") " ---- https://" gsubi("wiki", "", wpsite) ".wikipedia.org/w/index.php?diff=" revid " ---- " timestamp " ---- " epochdays >> "epochdiff.txt"
            #close("epochdiff.txt")
            continue
          }

          # determine if a revert by looking at tags
          # List of tags: https://en.wikipedia.org/wiki/Special:Tags .. each language has its own tags but they seem to be the same

          #if(jsonrev ~ /(Undo|revert|rollback|vandal)/) {
          #  print "1: " jsonrev >> logfile ".details.revert.debug.txt"
          #  close(logfile ".details.revert.debug.txt")
          #}

          numbtags = int(jsonreva["query","pages",pageid,"revisions","1","tags","0"])
          if( numbtags > 0) {
            for(ni = 1; ni <= numbtags; ni++) {
              if( jsonreva["query","pages",pageid,"revisions","1","tags",ni] ~ /(Undo|revert|rollback|vandal)/) {
                #print "2: " jsonrev >> logfile ".details.revert.debug.txt"
                #close(logfile ".details.revert.debug.txt")
                revert = 1
              }
              
            }
          }
        }

        # Look at IABot edit comments to determine who is responsible for the edit.
        if( length(URLZ1) > 0 || length(URLB1) > 0 || length(URLB3) > 0) {
          perp = "API:Revisions error"
          if(!empty(comment)) {
            if(comment ~ /GreenC bot/) 
              perp = "greencbot"
            else if(comment ~ /#IABot/) 
              perp = "iabot"
          }
        }

      }
    }

    # Edit is a revert. Skip.
    if( revert) {
      #print "3: " jsonrev >> logfile ".details.revert.debug.txt"
      #close(logfile ".details.revert.debug.txt")
      revert = 0
      continue
    }

    if(perp == "iabot" || perp == "greencbot" || perp == "user" || perp == "userbot" ) {

      if(length(URLZ1) > 0 || length(URLZ2) > 0 || length(URLZ3) > 0 || length(URLZ4) > 0 || length(URLB1) > 0 || length(URLB2) > 0 || length(URLB3) > 0 ) {

        # print web and book totals to logfile
        print gsubi("wiki$", "", wpsite) " " revid " " length(URLZ1) " " length(URLB1) " " length(URLB2) " " length(URLZ2) " " length(URLZ3) " " length(URLB3) >> logfile ".txt"
        close(logfile ".txt")

        # print web to stdout (logroll)
        if(length(URLZ1) > 0) {
          for(u in URLZ1) {
            for(k = 1; k <= URLZ1[u]; k++) {
              su = u
              sub("https?://web.archive.org/(web/)?[^/]*[/]", "", su)
              sus = substr(su, 1, 50)
              aus = substr(u, 1, 50)
              command = "<tr><td>" datetime "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"" su "\">" sus "</a></td> <td><a href=\"" u "\">" aus "</a></td> <td><a href=\"" uri "\">" wpname "</a></td></tr>"
              print command
            }
          }
        }

        # print book IDs to stdout (logroll) and to details.txt
        if(length(URLB1) > 0) {
          for(u in URLB1) {
            command = "<tr><td>" datetime "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" uri "\">" wpname "</a></td></tr>"
            print command
            #if(wpsite == "enwiki") {
            #  print json >> logfile ".details-en.debug.txt"
            #  close(logfile ".details.debug.txt")
            #}
            if(wpsite == "arzwiki") {
              #if(u == "periodictableits0000scer") {
              #  print json >> logfile ".details-arz.debug.txt"
              #  continue
              #}
              if(u == "naturesbuildingb0000emsl" || u == "elementsvisualex0000gray")
                continue
            }
            print u " " gsubi("wiki$", "", wpsite) " " revid " " perp >> logfile ".details.txt"

          }
          close(logfile ".details.txt")
        }
        if(length(URLB2) > 0) {
          for(u in URLB2) {
            command = "<tr><td>" datetime "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" uri "\">" wpname "</a></td></tr>"
            print command
            print u " " gsubi("wiki$", "", wpsite) " " revid " " perp >> logfile ".details.txt"
            #if(wpsite == "enwiki") {
            #  print json >> logfile ".details.debug.txt"
            #  close(logfile ".details.debug.txt")
            #}
          }
          close(logfile ".details.txt")
        }
        if(length(URLB3) > 0) {
          for(u in URLB3) {
            command = "<tr><td>" datetime "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" uri "\">" wpname "</a></td></tr>"
            print command
            print u " " gsubi("wiki$", "", wpsite) " " revid " " perp >> logfile ".details.txt"
          }
          close(logfile ".details.txt")
        }

        # print to userbots.txt
        if(length(URLZ3) > 0) {
          close(logfile ".userbots.txt")
          if(!checkexists(logfile ".userbots.txt")) 
            print wpsite " | " wpuser " | " length(URLZ3) >> logfile ".userbots.txt.temp"
          else {
            found = 0
            for(i = 1; i <= splitn(logfile ".userbots.txt", ub, i); i++) {
              split(ub[i], a, /[ ][|][ ]/)
              if(wpsite == a[1] && wpuser == a[2]) {
                print wpsite " | " wpuser " | " a[3] + length(URLZ3) >> logfile ".userbots.txt.temp"
                found = 1
              }
              else 
                print ub[i] >> logfile ".userbots.txt.temp"
            }
            if(found == 0) 
              print wpsite " | " wpuser " | " length(URLZ3) >> logfile ".userbots.txt.temp"
          }
          close(logfile ".userbots.txt.temp")
          if(checkexists(logfile ".userbots.txt.temp")) {
            sys2var("/usr/bin/sort " logfile ".userbots.txt.temp > " logfile ".userbots.txt")
            close(logfile ".userbots.txt")
            sys2var("/bin/rm -r " logfile ".userbots.txt.temp")
          }
        }

        # print to isitdead.txt for tracking if an archive URL is 404 or 200
        #if(length(URLZ4) > 0) {
        #  for(u in URLZ4) 
        #    print u >> Home "isitdead.running.txt"
        #}
        # Disabled Dec 4 2023 - not using it?

      }
    }


  } # while

}

function getlogfile(  curtime, year, doy) {

        # To be even more precise, format date string to "YYYY MM DD HH MM SS" and then
        #   year = strftime("%Y", mktime(<string>))
        #   doy = strftime("%j", mktime(<string>))
        # But below method is just as fast and low odds of error

        curtime = sys2var("/usr/bin/date -d \"" jsona["meta","dt"] "\" \"+%Y-%m-%d\"")
        year = splitx(curtime, "-", 1)
        doy = strftime("%j")

        if(!checkexists(G["dbdir"] year)) {
          sys2var("/bin/mkdir " G["dbdir"] year)
          makeCalendar(G["dbdir"], year)
        }

        return G["dbdir"] year "/" doy 

        # NOTE: to convert from a year (2020) and day of year (347) to a calander date:
        #  date -d "347 days -1 day 2020-01-01" +"%Y%m%d"

}

#
# Generate calendar.txt
#
function makeCalendar(DBDir, year,  i,d,month,day,doy,checkMonth,out) {

  out = G["dbdir"] year "/calendar.txt"

  for(i = 1; i <= 12; i++) {
    month = sprintf("%02d", i)
    printf sys2var("/usr/bin/date -d " year "-" month "-01" " +%m") " " sys2var("/usr/bin/date -d " year "-" month "-01" " +%B") " " >> out
    for(d = 1; d <= 31; d++) {
      day = sprintf("%02d", d)
      doy = strftime("%j", mktime(year " " month " " day " 01 01 01") )
      checkMonth = sys2var("/usr/bin/date -d \"" doy " days -1 day " year "-01-01\" +\"%m\"")
      if(month == checkMonth)
        printf doy " " >> out
    }
    print >> out
  }
  close(out)

}

