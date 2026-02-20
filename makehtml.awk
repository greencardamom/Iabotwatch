#!/usr/local/bin/awk -bE

#
# Generate HTML for iabotwatch.awk
# https://tools-static.wmflabs.org/botwikiawk/dashdaily.html
# /data/project/botwikiawk/www/static/dashdaily/2020/10

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

BEGIN { # Bot cfg

  _defaults = "home      = /home/greenc/toolforge/iabotwatch/ \
               version   = 1.0 \
               copyright = 2024"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "iabotwatch"
  Home = G["home"]
  Engine = 3
  Agent = "makehtml/iabotwatch acre User:GreenC enwiki"

  IGNORECASE = 1

  P["root"]  = G["home"] "wwwroot/"
  P["htmldir"]  = G["home"] "www/"
  P["db"]    = P["htmldir"] "db/"

}

@include "botwiki.awk"
@include "library.awk"

BEGIN { # Bot run

  setup()

  loadDataDaily()
  loadDataMonthly() # load monthly before yearly
  loadDataYearly() 

  makePageDaily()
  makePageMonthly()
  makePageYearly()

  makeLive()

}

# --------------------------------------------------------

#
# Add commas to a number
#
function coma(s) {
  return sprintf("%'d", s)
}


#
# Convert a day of year (1..366) in a give year to a given form
#
function doy2cal(year,doy,form) {
        # NOTE: to convert from a year (2020) and day of year (347) to a calander date:
        #  date -d "347 days -1 day 2020-01-01" +"%Y%m%d"
  return strip(sys2var(Exe["date"] " -d \"" doy " days -1 day " year "-01-01\" +\"" form "\""))
}

#
# Return "en.wikipedia" or "commons.wikimedia" etc..
#
function wutDomain(host) {

  if(host ~ /wikidata/) {        # host = wikidata
    return "wikidata"
  }
  else if(host ~ /wiktionary/) { # host = enwiktionary
    sub("wiktionary", "", host)
    return host ".wiktionary"
  }
  else if(host ~ /wikiquote/) {  # host = enwikiquote
    sub("wikiquote", "", host)
    return host ".wikiquote"
  }
  else if(host ~ /wikisource/) { # host = enwikisource
    sub("wikisource", "", host)
    return host ".wikisource"
  }
  else if(host ~ /wikinews/) {   # host = enwikinews
    sub("wikinews", "", host)
    return host ".wikinews"
  }
  else if(host ~ /wikivoyage/) { # host = enwikivoyage
    sub("wikivoyage", "", host)
    return host ".wikivoyage"
  }
  else if(host ~ /wikibooks/) {  # host = enwikibooks
    sub("wikibooks", "", host)
    return host ".wikibooks"
  }
  else if(host ~ /wikiversity/) { # host = enwikiversity
    sub("wikiversity", "", host)
    return host ".wikiversity"
  }
  else if(host ~ /^(incubator|commons|meta|species|wikitech)$/)
    return host ".wikimedia"

  return host ".wikipedia"

}

#
# Check if a cell should be italic ie. has no user contribs that day due to WP:IMPORT edit history carry over
#
function isItalic(lang,day,table,  url,fp,i,a,b,aa,ii,c,sw,sw2,sw3,so,su,ss) {

  if(P["curdoy"] != day && checkexists(P["ddir"] day ".italic.txt") ) {
    fp = readfile(P["ddir"] day ".italic.txt")

    if(fp ~ /===/) {  # New format 2021-01-02
      c = split(fp, a, /=== Start/)
      for(i = 1; i <= c; i++) {
        a[i] = strip(a[i])
        if(empty(a[i])) continue
        for(ii = 1; ii <= splitn(a[i] "\n", aa, ii); ii++) {
          aa[ii] = strip(aa[ii])
          if(empty(aa[ii]) || aa[ii] ~ /End /) continue
          if(aa[ii] ~ /^Web Table/) { sw = 1; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
          if(aa[ii] ~ /^Details Table/) { sw = 0; so = 1; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
          if(aa[ii] ~ /^Details Sim Table/) { sw = 0; so = 0; ss = 1; su = 0; sw2 = 0; sw3 = 0; continue }
          if(aa[ii] ~ /^Users Table/) { sw = 0; so = 0; ss = 0; su = 1; sw2 = 0; sw3 = 0; continue }
          if(aa[ii] ~ /^Web2 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 1; sw3 = 0; continue }
          if(aa[ii] ~ /^Web3 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 1; continue }
          if(sw && table == "web") 
            if(aa[ii] == lang) return 1
          if(sw2 && table == "web2") 
            if(aa[ii] == lang) return 1
          if(sw3 && table == "web3") 
            if(aa[ii] == lang) return 1
          if(so && table == "other") 
            if(aa[ii] == lang) return 1
          if(ss && table == "other") 
            if(aa[ii] == lang) return 1
          if(su && table == "other") 
            if(aa[ii] == lang) return 1
        }
      }
      return 0
    }
    else { # Old format
      if(table == "other") return 1
      for(i = 1; i <= splitn(fp "\n", a, i); i++) {
        split(a[i], b, " ")
        if(b[1] == lang) {
          return b[2]
        }
      }
      return 0
    }

  }

  return 0

  # Determine if IABot edited the wiki that day
  # TODO: this is an imperfect method since maybe it edited for web but not books needs edge case fine-tuning
  # WARNING: this can seriously slow it down - is it absolutely needed?

  url = "https://" wutDomain(lang) ".org/w/index.php?title=Special%3AContributions&contribs=user&target=InternetArchiveBot&namespace=&tagfilter=&start=" doy2cal(P["curyear"], day, "%Y-%m-%d") "&end=" doy2cal(P["curyear"], day, "%Y-%m-%d")
  fp = strip(http2var(url, 1))
  if(fp !~ /data-mw-revid/ && ! empty(fp))
    return 1
  return 0

}

#
# Generate navigation buttons
#
function navGen(class,  prev,nex,curr) {

  if(class == "daily") {
    prev = "Prev Month&nbsp;|&nbsp;"
    nex  = "Next Month&nbsp;|&nbsp;"
    curr = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily.html\">Curr Month</a>&nbsp;|&nbsp;"

    if(checkexists(P["htmldir"] P["prevyear"] "/" P["prevmonth"] ".html")) 
      prev = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/" P["prevyear"] "/" P["prevmonth"] ".html\">Prev Month</a>&nbsp;|&nbsp;"
    if(checkexists(P["htmldir"] P["nextyear"] "/" P["nextmonth"] ".html") || P["curdoy"] == P["lastday"]) 
      nex = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/" P["nextyear"] "/" P["nextmonth"] ".html\">Next Month</a>&nbsp;|&nbsp;"

    return prev nex curr
  }
  if(class == "monthly") {
    prev = "Prev Year&nbsp;|&nbsp;"
    nex  = "Next Year&nbsp;|&nbsp;"
    curr = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashmonthly.html\">Curr Year</a>&nbsp;|&nbsp;"

    if(checkexists(P["htmldir"] int(int(P["curyear"]) - 1) "/monthly.html")) 
      prev = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/" int(int(P["curyear"]) - 1) "/monthly.html\">Prev Year</a>&nbsp;|&nbsp;"
    if(checkexists(P["htmldir"] int(int(P["curyear"]) + 1) "/monthly.html")) 
      nex = "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/" int(int(P["curyear"]) + 1) "/monthly.html\">Next Year</a>&nbsp;|&nbsp;"

    return prev nex curr
  }

}

#
# Make redirect page
#
function MetaRedirect(url,      str) {

    str = "\
        <!DOCTYPE html>\n\
        <html><title>InternetArchiveBot Dashboard Daily Redirect</title>\n\
        <head><meta http-equiv=\"Content-Type\"\n\
        content=\"text/html; charset=utf-8\">\n\
        <!-- This code is licensed under GNU GPL v3 -->\n\
        <!-- You are allowed to freely copy, distribute and use this code, but removing author credit is strictly prohibited -->\n\
        <!-- Credit goes to http://insider.zone/ -->\n\
        <!-- Generated by http://insider.zone/tools/client-side-url-redirect-generator/ -->\n\
        <link rel=\"canonical\" href=\"" url "\"/>\n\
        <noscript>\n\
            <meta http-equiv=\"refresh\" content=\"0;URL=" url "\">\n\
        </noscript>\n\
        <script type=\"text/javascript\">\n\
            var _zoneurl = \"" url "\";\n\
            if(typeof IE_fix != \"undefined\") // IE8 and lower fix to pass the http referer\n\
            {\n\
                document.write(\"redirecting...\"); // Don't remove this line or appendChild() will fail because it is called before document.onload to make the redirect as fast as possible. Nobody will see this text, it is only a tech fix.\n\
                var referLink = document.createElement(\"a\");\n\
                referLink.href = _zoneurl;\n\
                document.body.appendChild(referLink);\n\
                referLink.click();\n\
            }\n\
            else { window.location.replace(_zoneurl); } // All other browsers\n\
        </script>\n\
        </head>\n\
        </html>\n"

    return str

}

#
# Standard table header with #, Site, Day 1..31
#
function tableheader(class, c,b,i,day,month,year,out) {
  
  out = P["html"]
  if(class == "monthly")
    out = P["htmlM"]
  if(class == "yearly")
    out = P["htmlY"]

  print "<table class=\"sortable\">" >> out
  print "<thead>" >> out
  print "  <tr>" >> out
  print "    <th><u>#</u></th>" >> out
  print "    <th><u>Site</u></th>" >> out

  if(class == "daily") {
    c = split(P["doys"], b, " ")
    for(i = 1; i <= c; i++) {
      day = strip(b[i])
      if(! empty(day)) 
        print "    <th><u>" doy2cal(P["curyear"], day, "%d") "</u></th>" >> out
    }
    print "    <th><u>Total by Site</u></th>" >> out
  }
  if(class == "monthly") {
    c = split(P["months"], b, " ")
    for(i = 1; i <= c; i++) {
      month = strip(b[i])
      if(!empty(month))
        print "    <th><u>" sys2var("date --date=\"2000-" month "-01\" \"+%b\"") "</u></th>" >> out
    }
    print "    <th><u>Total by Site</u></th>" >> out
  }
  if(class == "yearly") {
    c = split(P["years"], b, " ")
    for(i = 1; i <= c; i++) {
      year = strip(b[i])
      if(!empty(year))
        print "    <th><u>" year "</u></th>" >> out
    }
    print "    <th><u>Total by Year</u></th>" >> out
  }
  
  print "  </tr>" >> out
  print "</thead>" >> out
  print "<style type=\"text/css\">" >> out
  print "table.sortable tbody {" >> out
  print "  text-align: right;" >> out
  print "}" >> out
  print "table.sortable tfoot {" >> out
  print "  text-align: right;" >> out
  print "}" >> out
  print "</style>" >> out

}

#
# Print the total row for the columns
#   class = doys, months, years
#   L = TWMC, TDMC, TUMC, TW2MC, TW3MC, TWYC, TDYC, TUYC, TW2YC, TW3YC
#
function makeTableColumnsTotalRow(class, html, r, L, totalbysite,  c,i,b,period) {

  if(r > 0) {
    print "  <tr>" >> html
    print "      <td>Total</td>" >> html                     
    print "      <td>  </td>" >> html
    c = split(P[class], b, " ")
    for(i = 1; i <= c; i++) {
      period = strip(b[i])
      if(! empty(period)) 
        print "      <td>" coma(L[period]) "</td>" >> html
    }
    print "      <td>" coma(totalbysite) "</td>" >> html
    print "  </tr>"  >> html
  }

  print "</tfoot>" >> html
  print "</table>" >> html
  print "</center>" >> html
  print "<br>" >> html
  print "<br>" >> html

}

#
# print a yearly table
#  A = WY, DY, UY, W2Y, W3Y
#  C = TWYR, TDYR, TUYR, TW2YR, TW3YR
#  L = TWYC, TDYC, TUYC, TW2YC, TW3YC
#
function makeTableYearly(A, C, L, class,  k,c,b,i,year,totalbysite,r) {

  tableheader("yearly")

  print "<tbody>" >> P["htmlY"]
    
  PROCINFO["sorted_in"] = "@ind_str_asc"

  for(k in A) {
    print "  <tr>" >> P["htmlY"]
    print "      <td>" ++r ".</td>" >> P["htmlY"]
    print "      <td>" k "</td>" >> P["htmlY"]
    c = split(P["years"], b, " ")
    for(i = 1; i <= c; i++) {
      year = strip(b[i])
      if(! empty(year)) 
        print "      <td>" coma(A[k][year]) "</td>" >> P["htmlY"]
    }
    print "      <td>" coma(C[k]) "</td>" >> P["htmlY"]
    totalbysite = totalbysite + int(C[k])
    print "  </tr>" >> P["htmlY"]
  }
  print "</tbody>" >> P["htmlY"]
  print "<tfoot>" >> P["htmlY"]

  # Total of colums row

  makeTableColumnsTotalRow("years", P["htmlY"], r, L, totalbysite)

}

#
# Print HTML file yearly
#
function makePageYearly( i,k,r,b,c,month,totalbysite,date,url) {

  if(checkexists(G["home"] "headerdashyearly.html") && checkexists(G["home"] "footer.html") ) 
    print readfile(G["home"] "headerdashyearly.html") > P["htmlY"]
  else
    return

  print "<a name=\"top\"></a>" >> P["htmlY"]
  print "<center><h1><u>InternetArchiveBot Dashboard Yearly</u></h1></center>" >> P["htmlY"]
  #print "<center><h2>" P["curyear"] "</h2></center>" >> P["htmlY"]
  print "<center><a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily.html\">Dashboard Daily</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashmonthly.html\">Dashboard Monthly</a></center>" >> P["htmlY"]

# A. Web table

  print "<a name=\"Wayback Links added by IABot\"></a>" >> P["htmlY"]
  print "<center><h3>A. Wayback Links added by IABot</h3></center>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(WY, TWYR, TWYC, "web")

# B. Web table2

  print "<center><h3>B. Wayback Links added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlY"]
  print "<a name=\"Wayback Links added by Users\"></a>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(W2Y, TW2YR, TW2YC, "web2")

# C. Web table3

  print "<a name=\"Wayback Links added by User Bots\"></a>" >> P["htmlY"]
  print "<center><h3>C. Wayback Links added by User Bots&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(W3Y, TW3YR, TW3YC, "web3")

# D. Details table

  print "<a name=\"LAMP\"></a>" >> P["htmlY"]
  print "<center><h3>D. LAMP&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(DY, TDYR, TDYC, "details")

# E. Details sim table

  print "<a name=\"LAMP_SIM\"></a>" >> P["htmlY"]
  print "<center><h3>E. LAMP SIM&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(D2Y, TD2YR, TD2YC, "details")

# F. Users table

  print "<a name=\"Media Links (/details/) added by Users\"></a>" >> P["htmlY"]
  print "<center><h3>F. Media Links (/details/) added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlY"]
  print "<center>" >> P["htmlY"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlY"]

  makeTableYearly(UY, TUYR, TUYC, "users")

  print readfile(G["home"] "footer.html") >> P["htmlY"]
  close(P["htmlY"])
}

#
# print a monthly table
#  A = WM, DM, UM, W2M, W3M
#  C = TWMR, TDMR, TUMR, TW2MR, TW3MR
#  L = TWMC, TDMC, TUMC, TW2MC, TW3MC
#
function makeTableMonthly(A, C, L, class,  k,c,b,i,month,totalbysite,r) {

  tableheader("monthly")

  print "<tbody>" >> P["htmlM"]
    
  PROCINFO["sorted_in"] = "@ind_str_asc"

  for(k in A) {
    print "  <tr>" >> P["htmlM"]
    print "      <td>" ++r ".</td>" >> P["htmlM"]
    print "      <td>" k "</td>" >> P["htmlM"]
    c = split(P["months"], b, " ")
    for(i = 1; i <= c; i++) {
      month = strip(b[i])
      if(! empty(month)) 
        print "      <td>" coma(A[k][month]) "</td>" >> P["htmlM"]
    }
    print "      <td>" coma(C[k]) "</td>" >> P["htmlM"]
    totalbysite = totalbysite + int(C[k])
    print "  </tr>" >> P["htmlM"]
  }
  print "</tbody>" >> P["htmlM"]
  print "<tfoot>" >> P["htmlM"]

  # Total of colums row

  makeTableColumnsTotalRow("months", P["htmlM"], r, L, totalbysite)

}

#
# Print HTML file monthly
#
function makePageMonthly( i,k,r,b,c,month,totalbysite,date,url) {

  if(checkexists(G["home"] "headerdashdaily.html") && checkexists(G["home"] "footer.html") ) 
    print readfile(G["home"] "headerdashdaily.html") > P["htmlM"]
  else
    return

  print "<a name=\"top\"></a>" >> P["htmlM"]
  print "<center><h1><u>InternetArchiveBot Dashboard Monthly</u></h1></center>" >> P["htmlM"]
  print "<center><h2>" P["curyear"] "</h2></center>" >> P["htmlM"]
  print "<center>" navGen("monthly") "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily.html\">Dashboard Daily</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashyearly.html\">Dashboard Yearly</a></center>" >> P["htmlM"]

# A. Web table

  print "<a name=\"Wayback Links added by IABot\"></a>" >> P["htmlM"]
  print "<center><h3>A. Wayback Links added by IABot</h3></center>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(WM, TWMR, TWMC, "web")

# B. Web table2

  print "<center><h3>B. Wayback Links added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlM"]
  print "<a name=\"Wayback Links added by Users\"></a>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(W2M, TW2MR, TW2MC, "web2")

# C. Web table3

  print "<a name=\"Wayback Links added by User Bots\"></a>" >> P["htmlM"]
  print "<center><h3>C. Wayback Links added by User Bots&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(W3M, TW3MR, TW3MC, "web3")

# D. Details table

  print "<a name=\"LAMP\"></a>" >> P["htmlM"]
  print "<center><h3>D. LAMP&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(DM, TDMR, TDMC, "details")

# E. Details sim table

  print "<a name=\"LAMP_SIM\"></a>" >> P["htmlM"]
  print "<center><h3>E. LAMP SIM&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(D2M, TD2MR, TD2MC, "details")

# F. Users table

  print "<a name=\"Media Links (/details/) added by Users\"></a>" >> P["htmlM"]
  print "<center><h3>F. Media Links (/details/) added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["htmlM"]
  print "<center>" >> P["htmlM"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["htmlM"]

  makeTableMonthly(UM, TUMR, TUMC, "users")

  print readfile(G["home"] "footer.html") >> P["htmlM"]
  close(P["htmlM"])
}

#
# print a daily table
#  A = W, D, D2, U, W2, W3
#  C = TWR, TDR, TD2R, TUR, TW2R, TW3R
#  K = IW, ID, ID2, IU, IW2, IW3
#  L = TWC, TDC, TD2C, TUC, TW2C, TW3C
#
function makeTableDaily(A, C, K, L, class,  k,c,b,i,day,date,url,totalbysite,r) {

  tableheader("daily")

  print "<tbody>" >> P["html"]
    
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for(k in A) {

    if(C[k] < 1) continue  # skip if row is all zero's

    print "  <tr>" >> P["html"]
    print "      <td>" ++r ".</td>" >> P["html"]
    if(K[k] > 0)
      print "      <td><mark>" k "</mark></td>" >> P["html"]
    else
      print "      <td>" k "</td>" >> P["html"]
    c = split(P["doys"], b, " ")
    for(i = 1; i <= c; i++) {
      day = strip(b[i])
      if(! empty(day)) {
        date = P["curyear"] "-" doy2cal(P["curyear"], day, "%m-%d")
        if(class == "web3") {
          url = "none"
          if(checkexists(P["db"] P["curyear"] "/" day ".userbots.txt"))
            url = "https://tools-static.wmflabs.org/botwikiawk/dashdaily/db/" P["curyear"] "/" day ".userbots.txt"
        }
        else
          url = "https://" wutDomain(k) ".org/w/index.php?title=Special%3AContributions&contribs=user&target=InternetArchiveBot&namespace=&tagfilter=&start=" date "&end=" date
        if(A[k][day]["value"] > 0) {
          if(A[k][day]["italic"] == 0) {
            if(class == "users" || class == "web2") 
              print "      <td>" coma(A[k][day]["value"]) "</td>" >> P["html"]
            else {
              if(url != "none")
                print "      <td><a href=\"" url "\">" coma(A[k][day]["value"]) "</a></td>" >> P["html"]
              else
                print "      <td>" coma(A[k][day]["value"]) "</td>" >> P["html"]
            }
          }
          else
            print "      <td><i>" coma(A[k][day]["value"]) "</i></td>" >> P["html"]
        }
        else
          print "      <td>" coma(A[k][day]["value"]) "</td>" >> P["html"]
      }
    }
    print "      <td>" coma(C[k]) "</td>" >> P["html"]
    totalbysite = totalbysite + int(C[k])
    print "  </tr>" >> P["html"]
  }
  print "</tbody>" >> P["html"]
  print "<tfoot>" >> P["html"]

  # Total of colums row

  makeTableColumnsTotalRow("doys", P["html"], r, L, totalbysite)

}

#
# Print HTML file daily
#
function makePageDaily( i,k,r,b,c,day,totalbysite,date,url) {

  if(checkexists(G["home"] "headerdashdaily.html") && checkexists(G["home"] "footer.html") ) 
    print readfile(G["home"] "headerdashdaily.html") > P["html"]
  else
    return

  print "<a name=\"top\"></a>" >> P["html"]
  print "<center><h1><u>InternetArchiveBot Dashboard Daily</u></h1></center>" >> P["html"]
  print "<center><h2>" P["monthname"] " " P["curyear"] "</h2></center>" >> P["html"]
  print "<center>" navGen("daily") "<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/db/\">Data & Doc</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashboard.html\">Dashboard Classic</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/iabotwatch.html\">Log-roll</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashdaily/" P["curyear"] "/monthly.html\">Dashboard Monthly</a>&nbsp;|&nbsp;<a href=\"https://tools-static.wmflabs.org/botwikiawk/dashyearly.html\">Dashboard Yearly</a></center>" >> P["html"]

# A. Web added by IABot

  print "<a name=\"Wayback Links added by IABot\"></a>" >> P["html"]
  print "<center><h3>A. Wayback Links added by IABot</h3></center>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(W, TWR, IW, TWC, "web")

# B. Web added by Users

  print "<center><h3>B. Wayback Links added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["html"]
  print "<a name=\"Wayback Links added by Users\"></a>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(W2, TW2R, IW2, TW2C, "web2")

# C. Web added by User Bots

  print "<a name=\"Wayback Links added by User Bots\"></a>" >> P["html"]
  print "<center><h3>C. Wayback Links added by User Bots&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(W3, TW3R, IW3, TW3C, "web3")

# D. LAMP

  print "<a name=\"LAMP\"></a>" >> P["html"]
  print "<center><h3>D. LAMP&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(D, TDR, ID, TDC, "details")

# E. LAMP SIM

  print "<a name=\"LAMP_SIM\"></a>" >> P["html"]
  print "<center><h3>E. LAMP SIM&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(D2, TD2R, ID2, TD2C, "details")

# F. Media added by Users

  print "<a name=\"Media Links (/details/) added by Users\"></a>" >> P["html"]
  print "<center><h3>F. Media Links (/details/) added by Users&nbsp;<a href=\"#top\"><small><sup>[Top]</sup></small></a></h3></center>" >> P["html"]
  print "<center>" >> P["html"]
  print "Tables: <a href=\"#Wayback Links added by IABot\">A. Wayback by IABot</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by Users\">B. Wayback by Users</a>&nbsp;|&nbsp;<a href=\"#Wayback Links added by User Bots\">C. Wayback by User Bots</a>&nbsp;|&nbsp;<a href=\"#LAMP\">D. LAMP</a>&nbsp;|&nbsp;<a href=\"#LAMP_SIM\">E. LAMP SIM</a>&nbsp;|&nbsp;<a href=\"#Media Links (/details/) added by Users\">F. Media by Users</a>" >> P["html"]

  makeTableDaily(U, TUR, IU, TUC, "users")

  print readfile(G["home"] "footer.html") >> P["html"]
  close(P["html"])
}

#
# Total for a table row (left-right)
#
function totalRows(A, C, class,  k,t,p) {
  for(k in A) {
    t = 0
    for(p in A[k]) {
      if(class == "daily")
        t = t + int(A[k][p]["value"])
      else if(class == "monthly" || class == "yearly")
        t = t + int(A[k][p])
    }
    C[k] = t
  }
}

#
# Total for a table column (up-down)
#
function totalColumns(A, C, class,   c,i,b,k,p,period) {

  c = split(P[class], b, " ")
  for(i = 1; i <= c; i++) {
    period = strip(b[i])
    if(!empty(period)) {
      for(k in A) {
        for(p in A[k]) {
          if(p == period) {
            if(class == "doys") 
              C[period] = C[period] + int(A[k][p]["value"])
            else
              C[period] = C[period] + int(A[k][p])
          }
        }
      }
    }
  }

}

#
# Load data for yearly tables WY[], DY[] and UY[]
#
function loadDataYearly(cp,ap,ip,fpn,fp,c,a,i,ii,aa,sw,sw2,sw3,so,ss,su,b) {

  cp = split(P["years"], ap, " ")
  for(ip = 1; ip <= cp; ip++) {
    fpn = P["db"] ap[ip] "/yearly.txt"
    if(checkexists(fpn)) {
      fp = readfile(fpn)
      if(fp ~ /===/) {
        c = split(fp, a, /=== Start/)
        for(i = 1; i <= c; i++) {
          a[i] = strip(a[i])
          if(empty(a[i])) continue
          for(ii = 1; ii <= splitn(a[i] "\n", aa, ii); ii++) {
            aa[ii] = strip(aa[ii])
            if(empty(aa[ii]) || aa[ii] ~ /End /) continue
            if(aa[ii] ~ /^Web Table/) { sw = 1; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Details Table/) { sw = 0; so = 1; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Details Sim Table/) { sw = 0; so = 0; ss = 1; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Users Table/) { sw = 0; so = 0; ss = 0; su = 1; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Web2 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 1; sw3 = 0; continue }
            if(aa[ii] ~ /^Web3 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 1; continue }
            if(sw) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "WY[" b[1] "][" ap[ip] "] = " b[2]
                  WY[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(so) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "DY[" b[1] "][" ap[ip] "] = " b[2]
                  DY[b[1]][ap[ip]] = b[2]
                  DY["en"]["2020"] = 515928  # "magic number" ie. books added in 2020, before iabotwatch existed
                }
              }
            }
            else if(ss) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "D2Y[" b[1] "][" ap[ip] "] = " b[2]
                  D2Y[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(su) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "DY[" b[1] "][" ap[ip] "] = " b[2]
                  UY[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(sw2) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "W2Y[" b[1] "][" ap[ip] "] = " b[2]
                  W2Y[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(sw3) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "W3Y[" b[1] "][" ap[ip] "] = " b[2]
                  W3Y[b[1]][ap[ip]] = b[2]
                }
              }
            }
          }
        }
      }
    }
  }

  # Total for web rows (left-right) ie. TWYR
  totalRows(WY, TWYR, "yearly")

  # Total for details rows (left-right) ie. TDYR
  totalRows(DY, TDYR, "yearly")

  # Total for details sim rows (left-right) ie. TD2YR
  totalRows(D2Y, TD2YR, "yearly")

  # Total for users rows (left-right) ie. TUYR
  totalRows(UY, TUYR, "yearly")

  # Total for web2 rows (left-right) ie. TW2YR
  totalRows(W2Y, TW2YR, "yearly")

  # Total for web3 rows (left-right) ie. TW3YR
  totalRows(W3Y, TW3YR, "yearly")


  # Total for web columns (up-down) ie. TWYC
  totalColumns(WY, TWYC, "years")

  # Total for details columns (up-down) ie. TDYC
  totalColumns(DY, TDYC, "years")

  # Total for details sim columns (up-down) ie. TD2YC
  totalColumns(D2Y, TD2YC, "years")

  # Total for users columns (up-down) ie. TUYC
  totalColumns(UY, TUYC, "years")

  # Total for web2 columns (up-down) ie. TW2YC
  totalColumns(W2Y, TW2YC, "years")

  # Total for web3 columns (up-down) ie. TW3YC
  totalColumns(W3Y, TW3YC, "years")

}

#
# Load data for monthly tables WM[], DM[] and UM[]
#
function loadDataMonthly(cp,ap,ip,fpn,fp,c,a,i,ii,aa,sw,sw2,sw3,so,ss,su,b,k,p,t,bm,month) {

  cp = split(P["months"], ap, " ")
  for(ip = 1; ip <= cp; ip++) {
    fpn = P["ddir"] "totals_" ap[ip] ".txt"
    if(checkexists(fpn)) {
      fp = readfile(fpn)
      if(fp ~ /===/) {
        c = split(fp, a, /=== Start/)
        for(i = 1; i <= c; i++) {
          a[i] = strip(a[i])
          if(empty(a[i])) continue
          for(ii = 1; ii <= splitn(a[i] "\n", aa, ii); ii++) {
            aa[ii] = strip(aa[ii])
            if(empty(aa[ii]) || aa[ii] ~ /End /) continue
            if(aa[ii] ~ /^Web Table/) { sw = 1; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Details Table/) { sw = 0; so = 1; ss = 0; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Details Sim Table/) { sw = 0; so = 0; ss = 1; su = 0; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Users Table/) { sw = 0; so = 0; ss = 0; su = 1; sw2 = 0; sw3 = 0; continue }
            if(aa[ii] ~ /^Web2 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 1; sw3 = 0; continue }
            if(aa[ii] ~ /^Web3 Table/) { sw = 0; so = 0; ss = 0; su = 0; sw2 = 0; sw3 = 1; continue }
            if(sw) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "WM[" b[1] "][" ap[ip] "] = " b[2]
                  WM[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(so) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "DM[" b[1] "][" ap[ip] "] = " b[2]
                  DM[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(ss) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "D2M[" b[1] "][" ap[ip] "] = " b[2]
                  D2M[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(su) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "DM[" b[1] "][" ap[ip] "] = " b[2]
                  UM[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(sw2) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "W2M[" b[1] "][" ap[ip] "] = " b[2]
                  W2M[b[1]][ap[ip]] = b[2]
                }
              }
            }
            else if(sw3) {
              if(split(aa[ii], b, " ") == 2) {
                if(int(b[2]) > 0) {
                  # print "W3M[" b[1] "][" ap[ip] "] = " b[2]
                  W3M[b[1]][ap[ip]] = b[2]
                }
              }
            }
          }
        }
      }
    }
  }

  # Total for web rows (left-right) ie. TWMR
  totalRows(WM, TWMR, "monthly")

  # Total for details rows (left-right) ie. TDMR
  totalRows(DM, TDMR, "monthly")

  # Total for details sim rows (left-right) ie. TD2MR
  totalRows(D2M, TD2MR, "monthly")

  # Total for users rows (left-right) ie. TUMR
  totalRows(UM, TUMR, "monthly")

  # Total for web2 rows (left-right) ie. TW2MR
  totalRows(W2M, TW2MR, "monthly")

  # Total for web3 rows (left-right) ie. TW3MR
  totalRows(W3M, TW3MR, "monthly")


  # Total for web columns (up-down) ie. TWMC
  totalColumns(WM, TWMC, "months")

  # Total for details columns (up-down) ie. TDMC
  totalColumns(DM, TDMC, "months")

  # Total for details sim columns (up-down) ie. TD2MC
  totalColumns(D2M, TD2MC, "months")

  # Total for users columns (up-down) ie. TUMC
  totalColumns(UM, TUMC, "months")

  # Total for web2 columns (up-down) ie. TW2MC
  totalColumns(W2M, TW2MC, "months")

  # Total for web3 columns (up-down) ie. TW3MC
  totalColumns(W3M, TW3MC, "months")

  # Save yearly data ie. the monthly view row totals (left-right) 
  fp = P["ddir"] "yearly.txt"
  removefile2(fp)
  genFile(TWMR, "Web", fp)
  genFile(TDMR, "Details", fp)
  genFile(TD2MR, "Details Sim", fp)
  genFile(TUMR, "Users", fp)
  genFile(TW2MR, "Web2", fp)
  genFile(TW3MR, "Web3", fp)

}

#
# Generate a tracking file with totals
#
function genFile(A,class,fp,  p) {

  print "=== Start " class " Table ===" >> fp
  for(p in A) 
    print p " " A[p] >> fp
  print "=== End " class " Table ===" >> fp
  close(fp)
}

#
# Generate italic file
#
function genItalicFile(A,class,fp,   p,k) {

  print "=== Start " class " Table ===" >> fp
  for(p in A) {
    for(k in A[p]) {
      if(k > P["curdoy"]) continue
      if( int(A[p][k]["italic"]) > 0 ) {
        if(k == P["curdoy"]) {                            # Comment-out this line to generate italics.txt for every day
          # print p " " 1 >> P["ddir"] k ".italic.txt"
          print p >> P["ddir"] k ".italic.txt"
        }
      }
#      else {
#        if(k == P["curdoy"])                             # Comment-out this line to generate italics.txt for every day
#          print p " " 0 >> P["ddir"] k ".italic.txt"
#      }
      close(P["ddir"] k ".italic.txt")
    }
  }
  print "=== End " class " Table ===" >> fp
  close(fp)
}

#
# Generate italic array
#
function genItalicArray(A, C) {
  for(p in A) {
    zv = 0
    zi = 0
    for(k in A[p]) {
      if(int(A[p][k]["value"]) > 0 && int(A[p][k]["italic"]) == 0)
        zv++
      else if(int(A[p][k]["value"]) > 0 && int(A[p][k]["italic"]) > 0)
        zi++
    }
    if(int(zv) == 0 && int(zi) > 0)
      C[p] = 1
    else
      C[p] = 0
  }
}

#
# Load data from /db directory into W[] and D[]
#
function loadDataDaily( command,result,c,b,i,k,g,p,s,day,cwd,zv,zi,fp,file,_a,_T,_s) {

  cwd = sys2var("pwd")
  if(! chDir(P["ddir"]))
    return 0

  # Load wikisite names used in current month
  command = Exe["awk"] " 'BEGINFILE{if (ERRNO) nextfile}{a[$1]++}END{for(i in a) print i}' " P["doystxt"]
  split(sys2var(command), g, "\n")

  # Load W[] web and D[] details and U[] users
  c = split(P["doys"], b, " ")
  for(i = 1; i <= c; i++) {
    day = strip(b[i])
    if(! empty(day)) {

      delete _T
      file = day ".txt"
      if(checkexists(file)) {
        while ((getline < file) > 0) {
          if (split($0, _a, " ") < 8) continue
          _s = _a[1]
          _T[_s][1] += int(_a[3]) # IABot web
          _T[_s][2] += int(_a[4]) # IABot details
          _T[_s][3] += int(_a[5]) # User details
          _T[_s][4] += int(_a[6]) # User web
          _T[_s][5] += int(_a[7]) # User web bot
          _T[_s][6] += int(_a[8]) # IABot details sim
        }
        close(file)
      }

      for(k in g) {
        
        # Original logic restored exactly:
        W[g[k]][day]["value"] = int(_T[g[k]][1])          # IABot web
        if(int(W[g[k]][day]["value"]) > 0) 
          W[g[k]][day]["italic"] = int(isItalic(g[k], day, "web")) 
        else 
          W[g[k]][day]["italic"] = 0

        D[g[k]][day]["value"] = int(_T[g[k]][2])          # IABot details
        if(int(D[g[k]][day]["value"]) > 0) 
          D[g[k]][day]["italic"] = int(isItalic(g[k], day, "other")) 
        else 
          D[g[k]][day]["italic"] = 0

        D2[g[k]][day]["value"] = int(_T[g[k]][6])         # IABot details sim
        D2[g[k]][day]["italic"] = 0

        U[g[k]][day]["value"] = int(_T[g[k]][3])          # User details
        U[g[k]][day]["italic"] = 0
        # TODO: Italic disabled for user contribs doesn't seem to work
        #if(int(U[g[k]][day]["value"]) > 0) 
        #  U[g[k]][day]["italic"] = int(isItalic(g[k], day, "other")) 
        #else 
        #  U[g[k]][day]["italic"] = 0

        W2[g[k]][day]["value"] = int(_T[g[k]][4])         # User web
        W2[g[k]][day]["italic"] = 0

        W3[g[k]][day]["value"] = int(_T[g[k]][5])         # User web bot
        W3[g[k]][day]["italic"] = 0

      }

    }
  }

  # Generate italic.txt files
  fp = P["ddir"] P["curdoy"] ".italic.txt"
  removefile2(fp)
  genItalicFile(W, "Web", fp)
  genItalicFile(D, "Other", fp)
  genItalicFile(D2, "Other Sim", fp)
  genItalicFile(U, "Users", fp)

  # Determine if a row in W[] is all italics (info to be saved in IW[])
  genItalicArray(W, IW)

  # Determine if a row in D[] is all italics (info to be saved in ID[])
  genItalicArray(D, ID)

  # Determine if a row in D2[] is all italics (info to be saved in ID2[])
  genItalicArray(D2, ID2)

  # Determine if a row in U[] is all italics (info to be saved in IU[])
  genItalicArray(U, IJ)

  # Determine if a row in W2[] is all italics (info to be saved in IW2[])
  genItalicArray(W2, IW2)

  # Determine if a row in W3[] is all italics (info to be saved in IW3[])
  genItalicArray(W3, IW3)

  # Generate active_<01-12>.txt
  fp = P["ddir"] "active_" P["curmonth"] ".txt"
  removefile2(fp)
  for(p in W) {
    if(IW[p] == 0) {
      print p >> fp 
      IW["active_sites"]++
    }
  }
  close(fp)

  # Total for web rows (left-right) ie. TWR
  totalRows(W, TWR, "daily")

  # Total for details rows (left-right) ie. TDR
  totalRows(D, TDR, "daily")

  # Total for details sim rows (left-right) ie. TD2R
  totalRows(D2, TD2R, "daily")

  # Total for users rows (left-right) ie. TUR
  totalRows(U, TUR, "daily")

  # Total for web2 rows (left-right) ie. TW2R
  totalRows(W2, TW2R, "daily")

  # Total for web3 rows (left-right) ie. TW3R
  totalRows(W3, TW3R, "daily")

  # Total for web columns (up-down) ie. TWC
  totalColumns(W, TWC, "doys")

  # Total for details columns (up-down) ie. TDC
  totalColumns(D, TDC, "doys")

  # Total for details sim columns (up-down) ie. TD2C
  totalColumns(D2, TD2C, "doys")

  # Total for users columns (up-down) ie. TUC
  totalColumns(U, TUC, "doys")

  # Total for web2 columns (up-down) ie. TW2C
  totalColumns(W2, TW2C, "doys")

  # Total for web3 columns (up-down) ie. TW3C
  totalColumns(W3, TW3C, "doys")

  # Generate totals_<01-12>.txt files
  fp = P["ddir"] "totals_" P["curmonth"] ".txt"
  removefile2(fp)

  # Save totals_01.txt data ie. the monthly rows (left-right) totals 
  genFile(TWR, "Web", fp)
  genFile(TDR, "Details", fp)
  genFile(TD2R, "Details Sim", fp)
  genFile(TUR, "Users", fp)
  genFile(TW2R, "Web2", fp)
  genFile(TW3R, "Web3", fp)

  chDir(cwd)

}

#
# Check if exist and create dirs, dates, redir
#
function setup(  i,a,b,k,c,l) {

  P["curyear"]  = strftime("%Y")
  P["curmonth"] = strftime("%m")
  P["curday"]   = strftime("%d")
  P["curdoy"]   = sys2var(Exe["date"] " -d \"" P["curyear"] "-" P["curmonth"] "-" P["curday"] "\" \"+%j\"")

  # Generate redirect pages
  print MetaRedirect("https://tools-static.wmflabs.org/botwikiawk/dashdaily/" P["curyear"] "/" P["curmonth"] ".html") > P["root"] "dashdaily.html"
  close(P["root"] "dashdaily.html")
  print MetaRedirect("https://tools-static.wmflabs.org/botwikiawk/dashdaily/" P["curyear"] "/monthly.html") > P["root"] "dashmonthly.html"
  close(P["root"] "dashmonthly.html")

  # Destination html file for current month daily view
  if(! checkexists(P["htmldir"] P["curyear"]))
    mkdir(P["htmldir"] P["curyear"])
  P["html"] = P["htmldir"] P["curyear"] "/" P["curmonth"] "Z1.html"

  # Destination html file for monthly view
  P["htmlM"] = P["htmldir"] P["curyear"] "/monthlyZ1.html"

  # Destination html file for yearly view
  P["htmlY"] = P["root"] "/dashyearlyZ1.html"

  # Destination db dir for current year
  if(! checkexists(P["db"] year)) {
    stdErr("Unable to make DB dir")
    return
  }
  P["ddir"] = P["db"] P["curyear"] "/"

  # Create P["doys"] (list of days in current month) from calendar.txt (generated in iabotwatch.awk)
  if(! checkexists(P["ddir"] "calendar.txt")) {
    stdErr("Unable to find " P["ddir"] "calendar.txt")
    return
  }
  for(i = 1; i <= splitn(P["ddir"] "calendar.txt", a, i); i++) {
    if(P["curmonth"] == splitx(a[i], " ", 1)) {
      c = split(a[i], b, " ")
      for(k = 2; k <= c; k++) {
        if(k == 2)
          P["monthname"] = b[k]
        else {
          if(! empty(strip(b[k]))) {
            P["doys"] = P["doys"] " " strip(b[k])
            P["doystxt"] = P["doystxt"] " " strip(b[k]) ".txt"
          }
        }
      }
      P["doys"] = strip(P["doys"])
      P["doystxt"] = strip(P["doystxt"])
      break
    }
  }

  # Generate last day of current month in doy form eg. last day of April is 120

  # Test: awk -ilibrary -v month="07" 'BEGIN{l = sys2var(Exe["date"] " -d \"$(/bin/date +%Y-%m-01) + 1 month - 1 day\" +%d"); print strftime("%j", mktime("2021 " month " " l " 01 01 01") )  }'
  l = sys2var(Exe["date"] " -d \"$(/bin/date +%Y-%m-01) +1 month -1 day\" +%d")
  P["lastday"] = strftime("%j", mktime(P["curyear"] " " P["curmonth"] " " l " 01 01 01") )

  P["months"] = "01 02 03 04 05 06 07 08 09 10 11 12"

  # Generate prev and next year/month from current for navigating links
  P["prevyear"] = P["curyear"]
  P["prevmonth"] = sprintf("%02d", int(P["curmonth"]) - 1)
  if(P["curmonth"] == "01") { 
    P["prevmonth"] = "12"
    P["prevyear"] = int(P["curyear"]) - 1
  }
  P["nextyear"] = P["curyear"]
  P["nextmonth"] = sprintf("%02d", int(P["curmonth"]) + 1)  
  if(P["curmonth"] == "12") { 
    P["nextmonth"] = "01"
    P["nextyear"] = int(P["curyear"]) + 1
  }

  # Print skeleton HTML for next month if it is the last day of the current month.
  if(! checkexists(P["htmldir"] P["nextyear"]))
    mkdir(P["htmldir"] P["nextyear"])
  if(P["curdoy"] == P["lastday"]) {
    print "<pre>Next month unavailable. Current month still active.</pre>" > P["htmldir"] P["nextyear"] "/" P["nextmonth"] ".html"
    close(P["htmldir"] P["nextyear"] "/" P["nextmonth"] ".html")
  }

  # Generate array of avail years eg. P["years"] = "2020 2021 2022"
  for(i = 1; i <= splitn(sys2var(Exe["ls"] " " P["db"] " | " Exe["grep"] " -E \"^20\""), a, i); i++) 
    P["years"] = P["years"] " " strip(a[i])
  P["years"] = strip(P["years"])


}

#
# Move temporary files to live HTML
#
function makeLive(  new) {

  new = gsubi("Z1", "", P["html"])
  sys2var(Exe["mv"] " " shquote(P["html"]) " " shquote(new))
  new = gsubi("Z1", "", P["htmlM"])
  sys2var(Exe["mv"] " " shquote(P["htmlM"]) " " shquote(new))
  new = gsubi("Z1", "", P["htmlY"])
  sys2var(Exe["mv"] " " shquote(P["htmlY"]) " " shquote(new))

  sys2var("/home/greenc/toolforge/scripts/push iabotwatchroot v")
  sys2var("/home/greenc/toolforge/scripts/push iabotwatch v")

}

