# The MIT License (MIT)
# Copyright (c) 2020-2024 by User:GreenC (at en.wikipedia.org)

BEGIN {
    IGNORECASE = 1

    while ((getline line < "/dev/stdin") > 0) {
        json = strip(line)
        
        if( query_json(json, jsona) >= 0) {
            
            # 1. Does it have added links?
            if(int(jsona["added_links","0"]) > 0) {
                
                # 2. Is it in Main (0) or File (6) namespace?
                pagens = jsona["page_namespace"]
                if(pagens !~ /^(0|6)$/) continue

                # 3. Apply specific wiki exclusions
                wpsite = jsona["database"]
                uri = jsona["meta", "uri"]
                if(wpsite == "commonswiki" && uri ~ "[_]page[_]") continue

                # 4. Verify it actually contains an archive/book link
                has_hit = 0
                nadded = int(jsona["added_links","0"])
                
                for(j = 1; j <= nadded; j++) {
                    if(jsona["added_links",j,"external"] == 1) {
                        url = urldecodeawk(urldecodeawk(jsona["added_links",j,"link"]))
                        
                        if(url ~ "https://web.archive.org/web/" || url ~ "/archive.org/details/" || url ~ /[?]Expires=/) {
                            has_hit = 1
                            break
                        }
                    }
                }

                # 5. FAST-PATH EXPORT
                if (has_hit == 1) {
                    print json
                    fflush() # Force write to disk so data survives if curl drops
                }
            }
        }
    }
}
