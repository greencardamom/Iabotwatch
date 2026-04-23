#!/usr/local/bin/awk -bf
@include "library"
@include "json"

# The MIT License (MIT)
# Copyright (c) 2020-2024 by User:GreenC (at en.wikipedia.org)
#
# Permission is hereby granted... (Standard MIT License applies)

BEGIN {
    _defaults = "home      = /home/greenc/toolforge/iabotwatch/ \
                 awsexp    = /home/greenc/toolforge/awsexp/ \
                 emailfp   = /home/greenc/scripts/secrets/greenc.email \
                 userid    = User:GreenC \
                 version   = 1.5 \
                 copyright = 2026"

    asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
    BotName = "iabotwatch"
    Home = G["home"]
    Agent = BotName "-" G["version"] "-" G["copyright"] " (" G["userid"] "; mailto:" strip(readfile(G["emailfp"])) ")"
    
    IGNORECASE = 1
    
    # Live Environment Paths
    G["dbdir"] = G["home"] "www/db/"
    G["chunkfragment"] = G["home"] "cache/chunkfragment.html"

    # Make sure we start with a fresh fragment file for this batch
    sys2var("rm -f " G["chunkfragment"])
}

# ==============================================================================
# PASS 1: NATIVE STREAM CONSUMER (Reads all cache.* files passed via CLI)
# ==============================================================================
{
    json = strip($0)
    if (json == "") next

    delete URLZ1; delete URLZ2; delete URLZ3; delete URLZ4
    delete URLB1; delete URLB2; delete URLB3

    if( query_json(json, jsona) >= 0) {
        if(int(jsona["added_links","0"]) > 0) {
            nadded = int(jsona["added_links","0"])
            
            # Extract Core Metadata
            uri = jsona["meta", "uri"]
            wpdomain = jsona["meta", "domain"]
            wpsite  = jsona["database"]
            pageid  = jsona["page_id"]
            revid   = jsona["rev_id"]
            pagens  = jsona["page_namespace"]
            wpname  = gsubi("_", " ", jsona["page_title"])
            gsub(/[\r\n\t]/, "", wpname)
            wpuser  = jsona["performer","user_text"]
            wpisbot = jsona["performer","user_is_bot"]

            if(pagens !~ /^(0|6)$/) next
            if(wpsite == "commonswiki" && uri ~ "[_]page[_]") next

            if(wpsite == "zh_yuewiki") wpsite = "zh-yuewiki"
            if(wpsite == "be_x_oldwiki") wpsite = "be-taraskwiki"

            # Timezone Math
            safe_dt = jsona["meta","dt"]
            gsub(/[-T:Z]/, " ", safe_dt)
            unix_dt = mktime(safe_dt, 1) 
            
            # Generate Pacific string for the HTML Report
            old_tz = ENVIRON["TZ"]
            ENVIRON["TZ"] = "US/Pacific"
            datetime = strftime("%Y-%m-%dT%H:%M:%S", unix_dt)
            if (old_tz != "") ENVIRON["TZ"] = old_tz; else delete ENVIRON["TZ"]

            perp = (int(wpisbot) == 1) ? "userbot" : "user"

            # URL Parsing
            for(j = 1; j <= nadded; j++) {
                if(jsona["added_links",j,"external"] == 1) {
                    url = urldecodeawk(urldecodeawk(jsona["added_links",j,"link"]))
                    gsub(/[\r\n\t]/, "", url)

                    if(url ~ "https://web.archive.org/web/") {
                        if(wpuser ~ "InternetArchiveBot") {
                            URLZ1[url]++; URLZ4[url]++
                        } else if(perp ~ "userbot") {
                            URLZ3[url]++
                        } else {
                            URLZ2[url]++
                        }
                    }

                    if(url ~ "/archive.org/details/") {
                        if(match(url, "details[/][^$/]+[^$/]", d) > 0) {
                            key = gsubi("(details[/]|[/]page[/][^$/]+[^$/])","",d[0])
                            if(json ~ "InternetArchiveBot") {
                                if(!(wpsite == "arzwiki" && (key == "periodictableits0000scer" || key == "naturesbuildingb0000emsl" || key == "elementsvisualex0000gray"))) {
                                    if(url ~ "/details/sim_") URLB3[key] = 1
                                    else URLB1[key] = 1
                                }
                            } else URLB2[key] = 1
                        }
                    }

                    if(url ~ /[?]Expires=/ && wpsite == "enwiki") {
                        print wpname " ---- " url " ---- " strftime("%Y%m%dT%H:%M:%S", systime()) >> G["awsexp"] "dropoff.txt"
                        close(G["awsexp"] "dropoff.txt")
                    }
                }
            }

            # --- CACHE THE HIT IN MEMORY FOR BATCHING ---
            if(length(URLZ1)>0 || length(URLB1)>0 || length(URLB3)>0 || length(URLZ2)>0 || length(URLZ3)>0 || length(URLB2)>0) {
                
                # Append to domain-specific pipe string
                if (DomainChunks[wpdomain] == "") DomainChunks[wpdomain] = revid
                else DomainChunks[wpdomain] = DomainChunks[wpdomain] "|" revid
            
                # Save Data
                HitData[revid, "wpsite"]   = wpsite
                HitData[revid, "wpname"]   = wpname
                HitData[revid, "uri"]      = uri
                HitData[revid, "datetime"] = datetime  # <--- Pacific Time for HTML
                HitData[revid, "unix_dt"]  = unix_dt   # <--- Raw epoch for GMT Database
                HitData[revid, "wpuser"]   = wpuser
                HitData[revid, "perp"]     = perp            
                            
                # Copy dynamic arrays, separated by || to save memory
                for(u in URLZ1) HitLists[revid, "Z1"] = HitLists[revid, "Z1"] u "|" URLZ1[u] "||"
                for(u in URLZ2) HitLists[revid, "Z2"] = HitLists[revid, "Z2"] u "|" URLZ2[u] "||"
                for(u in URLZ3) HitLists[revid, "Z3"] = HitLists[revid, "Z3"] u "|" URLZ3[u] "||"
                for(u in URLB1) HitLists[revid, "B1"] = HitLists[revid, "B1"] u "|" URLB1[u] "||"
                for(u in URLB2) HitLists[revid, "B2"] = HitLists[revid, "B2"] u "|" URLB2[u] "||"
                for(u in URLB3) HitLists[revid, "B3"] = HitLists[revid, "B3"] u "|" URLB3[u] "||"
            }
        }
    }
}

# ==============================================================================
# PASS 2: BATCH API FETCH AND HTML GENERATION
# ==============================================================================
END {
    for (domain in DomainChunks) {
        
        # Split all revids for this domain into an array
        total_revs = split(DomainChunks[domain], RevArray, "|")
        
        # Fire API in chunks of 50
        for (i = 1; i <= total_revs; i += 50) {
            
            chunk = RevArray[i]
            for (j = i + 1; j < i + 50 && j <= total_revs; j++) {
                chunk = chunk "%7C" RevArray[j]
            }
            
            # Fetch using %7C encoding and explicitly request ids
            commandurl = "https://" domain "/w/api.php?action=query&prop=revisions&revids=" chunk "&rvprop=ids%7Ccomment%7Ctags%7Ctimestamp&format=json"
            batch_json = wmf_api_fetch(commandurl)
            
            delete batch_jsona
            if (query_json(batch_json, batch_jsona) >= 0) {
                
                # Match comments/tags to the correct revids
                for (key in batch_jsona) {
                    if (key ~ /revid$/) {
                        r_id = batch_jsona[key]
                        
                        # Extract the array prefix (e.g. "query,pages,1234,revisions,0,")
                        prefix = substr(key, 1, length(key) - 5)
                        
                        comment = batch_jsona[prefix "comment"]
                        timestamp = batch_jsona[prefix "timestamp"]
                        
                        # Check tags for reverts
                        revert = 0
                        for (t in batch_jsona) {
                            if (t ~ "^" prefix "tags," && batch_jsona[t] ~ /(Undo|revert|rollback|vandal)/) {
                                revert = 1
                                break
                            }
                        }

                        # Process this specific revid
                        process_revid(r_id, comment, timestamp, revert)
                    }
                }
            }
        }
    }

    # --- CHRONOLOGICAL SORTING BLOCK ---
    # Force GNU Awk to sort the array keys alphabetically (sorting by ISO timestamp)
    PROCINFO["sorted_in"] = "@ind_str_asc"
    for (key in HtmlOut) {
        print HtmlOut[key] >> G["chunkfragment"]
    }
    close(G["chunkfragment"])

    # --- FLUSH USERBOT TALLIES TO DISK ---
    for (combo in UserbotCounts) {
        split(combo, parts, SUBSEP)
        target_log = parts[1]
        t_wpsite = parts[2]
        t_wpuser = parts[3]
        
        # Read existing file to memory to append/update
        delete ExistingUB
        if (checkexists(target_log ".userbots.txt")) {
            while ((getline _ub_line < (target_log ".userbots.txt")) > 0) {
                split(_ub_line, _ub_arr, /[ ][|][ ]/)
                ExistingUB[_ub_arr[1], _ub_arr[2]] = int(_ub_arr[3])
            }
            close(target_log ".userbots.txt")
        }
        
        # Update memory count
        ExistingUB[t_wpsite, t_wpuser] += UserbotCounts[combo]
        
        # Rewrite the file sorted
        temp_ub_file = "/tmp/iabw_ub_" PROCINFO["pid"] ".tmp"
        sys2var("rm -f " temp_ub_file)
        for (ub_combo in ExistingUB) {
            split(ub_combo, ub_parts, SUBSEP)
            print ub_parts[1] " | " ub_parts[2] " | " ExistingUB[ub_combo] >> temp_ub_file
        }
        close(temp_ub_file)
        sys2var("/usr/bin/sort " temp_ub_file " > " target_log ".userbots.txt")
        sys2var("rm -f " temp_ub_file)
    }
}

# ==============================================================================
# HELPER: PROCESS A SINGLE VALIDATED REVID
# ==============================================================================
function process_revid(revid, comment, timestamp, revert,    perp, wpsite, logfile, u, i, k, arrZ1, arrZ2, arrZ3, arrB1, arrB2, arrB3, url_data, lenZ1, lenZ2, lenZ3, lenB1, lenB2, lenB3, count, su, sus, aus, clean_wpsite, _line, _arr, safe_api_dt, api_unix_dt) {
    
    if (revert == 1) return

    # --- TIME DRIFT & PHANTOM EDIT FILTER ---
    # Only run the time filter if the API successfully returned a timestamp
    if (timestamp != "") {
        safe_api_dt = timestamp
        gsub(/[-T:Z]/, " ", safe_api_dt)
        api_unix_dt = mktime(safe_api_dt, 1)

        if (api_unix_dt > 0) {
            # Discard if the revision is >24 hours older than the stream event
            if ((HitData[revid, "unix_dt"] - api_unix_dt) > 86400) return
            
            # Discard if the WMF server clock drifted >60s into the future (T303907)
            if ((systime() - api_unix_dt) < -60) return
        }
    }
    # ----------------------------------------

    perp = HitData[revid, "perp"]
    wpsite = HitData[revid, "wpsite"]

    # Refine perp based on comment
    if (HitLists[revid, "Z1"] != "" || HitLists[revid, "B1"] != "" || HitLists[revid, "B3"] != "") {
        if (comment != "") {
            if (comment ~ /GreenC bot/) perp = "greencbot"
            else if (comment ~ /#IABot/) perp = "iabot"
        } else {
            if (HitData[revid, "wpuser"] ~ /InternetArchiveBot/) perp = "iabot"
            else if (HitData[revid, "wpuser"] ~ /GreenC bot/) perp = "greencbot"
        }
    }

    if (perp !~ /^(iabot|greencbot|user|userbot)$/) return

    # Get logfile path (Pass raw unix time for strict GMT sorting)
    logfile = getlogfile(HitData[revid, "unix_dt"])

    # --- DEDUPLICATION LOGIC ---
    clean_wpsite = gsubi("wiki$", "", wpsite)
    if (LoadedLogfiles[logfile] == "") {
        LoadedLogfiles[logfile] = 1
        if (checkexists(logfile ".txt")) {
            while ((getline _line < (logfile ".txt")) > 0) {
                split(_line, _arr, " ")
                if (_arr[2] != "") ProcessedRevids[_arr[1] "_" _arr[2]] = 1
            }
            close(logfile ".txt")
        }
    }
    if (ProcessedRevids[clean_wpsite "_" revid] == 1) return
    ProcessedRevids[clean_wpsite "_" revid] = 1

    # Decode counts
    lenZ1 = (HitLists[revid, "Z1"] == "") ? 0 : split(HitLists[revid, "Z1"], arrZ1, "\\|\\|") - 1
    lenZ2 = (HitLists[revid, "Z2"] == "") ? 0 : split(HitLists[revid, "Z2"], arrZ2, "\\|\\|") - 1
    lenZ3 = (HitLists[revid, "Z3"] == "") ? 0 : split(HitLists[revid, "Z3"], arrZ3, "\\|\\|") - 1
    lenB1 = (HitLists[revid, "B1"] == "") ? 0 : split(HitLists[revid, "B1"], arrB1, "\\|\\|") - 1
    lenB2 = (HitLists[revid, "B2"] == "") ? 0 : split(HitLists[revid, "B2"], arrB2, "\\|\\|") - 1
    lenB3 = (HitLists[revid, "B3"] == "") ? 0 : split(HitLists[revid, "B3"], arrB3, "\\|\\|") - 1

    # Print to master logfile
    print clean_wpsite " " revid " " lenZ1 " " lenB1 " " lenB2 " " lenZ2 " " lenZ3 " " lenB3 >> logfile ".txt"
    close(logfile ".txt")
    
    # --- RESTORED USERBOT TALLY ---
    if (lenZ3 > 0) {
        UserbotCounts[logfile, clean_wpsite, HitData[revid, "wpuser"]] += lenZ3
    }

    # Generate HTML Rows...
    if (lenZ1 > 0) {
        for (i=1; i<=lenZ1; i++) {
            split(arrZ1[i], url_data, "\\|")
            u = url_data[1]; count = int(url_data[2])
            for(k=1; k<=count; k++) {
                su = u; sub("https?://web.archive.org/(web/)?[^/]*[/]", "", su)
                sus = substr(su, 1, 50); aus = substr(u, 1, 50)
                HtmlOut[HitData[revid, "datetime"] "_" revid "_Z1_" i "_" k] = "<tr><td>" HitData[revid, "datetime"] "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"" su "\">" sus "</a></td> <td><a href=\"" u "\">" aus "</a></td> <td><a href=\"" HitData[revid, "uri"] "\">" HitData[revid, "wpname"] "</a></td></tr>"
            }
        }
    }

    if (lenB1 > 0) {
        for (i=1; i<=lenB1; i++) {
            split(arrB1[i], url_data, "\\|"); u = url_data[1]
            if (u ~ /[?]query/) continue
            HtmlOut[HitData[revid, "datetime"] "_" revid "_B1_" i] = "<tr><td>" HitData[revid, "datetime"] "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" HitData[revid, "uri"] "\">" HitData[revid, "wpname"] "</a></td></tr>"
            print u " " clean_wpsite " " revid " " perp >> logfile ".details.txt"
        }
        close(logfile ".details.txt")
    }
    
    if (lenB2 > 0) {
        for (i=1; i<=lenB2; i++) {
            split(arrB2[i], url_data, "\\|"); u = url_data[1]
            HtmlOut[HitData[revid, "datetime"] "_" revid "_B2_" i] = "<tr><td>" HitData[revid, "datetime"] "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" HitData[revid, "uri"] "\">" HitData[revid, "wpname"] "</a></td></tr>"
            print u " " clean_wpsite " " revid " " perp >> logfile ".details.txt"
        }
        close(logfile ".details.txt")
    }

    if (lenB3 > 0) {
        for (i=1; i<=lenB3; i++) {
            split(arrB3[i], url_data, "\\|"); u = url_data[1]
            HtmlOut[HitData[revid, "datetime"] "_" revid "_B3_" i] = "<tr><td>" HitData[revid, "datetime"] "</td> <td>" wpsite "</td> <td>" perp "</td> <td><a href=\"https://archive.org/details/" u "\">" u "</a></td> <td>n/a</td> <td><a href=\"" HitData[revid, "uri"] "\">" HitData[revid, "wpname"] "</a></td></tr>"
            print u " " clean_wpsite " " revid " " perp >> logfile ".details.txt"
        }
        close(logfile ".details.txt")
    }
}


function getlogfile(unix_dt,  year, doy) {
    # Generate DB paths natively in GMT/UTC
    year = strftime("%Y", unix_dt, 1)
    doy = strftime("%j", unix_dt, 1)

    if(!checkexists(G["dbdir"] year)) {
        sys2var("/bin/mkdir -p " G["dbdir"] year)
        makeCalendar(G["dbdir"], year)
    }
      
    return G["dbdir"] year "/" doy 
}

function wmf_api_fetch(url,  command, op) {
     command = "wikiget -U " shquote(url)
     op = sys2var(command)
     return op
}
