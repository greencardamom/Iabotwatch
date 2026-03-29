#!/usr/bin/env tcsh

#
# Script to reconcile local logs vs. eventstream logs and backfill database with missing entries
# Can be run manually for historical ranges, or automatically via cron using --current
#

# 1. Defaults
set rec_months = "1-12"
set html_months = ( 01 02 03 04 05 06 07 08 09 10 11 12 )
set show_usage = 0

# 2. Validate Input
if ( $#argv == 0 ) set show_usage = 1
if ( $#argv > 0 ) then
    if ( ("$1" == "--current" || "$1" == "--last") && $#argv != 2 ) set show_usage = 1
    if ( ("$1" == "--current" || "$1" == "--last") && $#argv == 2 && "$2" != "year" && "$2" != "month" ) set show_usage = 1
endif

if ( $show_usage == 1 ) then
    echo "Usage: $0 <year> OR <start_year-end_year> OR --current <year|month> OR --last <year|month>"
    echo "Example 1: $0 2024"
    echo "Example 2: $0 --last month  (Processes the previous month)"
    echo "Example 3: $0 --last year   (Processes the previous year)"
    exit 1
endif


# 3. Parse Modes
if ( "$1" == "--current" ) then
    set cur_year = `date +%Y`
    set start_year = $cur_year
    set end_year = $cur_year
    
    if ( "$2" == "year" ) then
        set input = "Current Year ($cur_year)"
    else if ( "$2" == "month" ) then
        set cur_month = `date +%m`
        set rec_months = $cur_month
        set html_months = ( $cur_month )
        set input = "Current Month ($cur_year-$cur_month)"
    endif

else if ( "$1" == "--last" ) then
    if ( "$2" == "year" ) then
        set cur_year = `date -d "last year" +%Y`
        set start_year = $cur_year
        set end_year = $cur_year
        set input = "Last Year ($cur_year)"
    else if ( "$2" == "month" ) then
        set cur_year = `date -d "last month" +%Y`
        set cur_month = `date -d "last month" +%m`
        set start_year = $cur_year
        set end_year = $cur_year
        set rec_months = $cur_month
        set html_months = ( $cur_month )
        set input = "Last Month ($cur_year-$cur_month)"
    endif

else
    set input = $1
    if ( "$input" =~ *-* ) then
        set start_year = `echo $input | cut -d'-' -f1`
        set end_year   = `echo $input | cut -d'-' -f2`
    else
        set start_year = $input
        set end_year   = $input
    endif
endif

# 4. Process
foreach year ( `seq $start_year $end_year` )
    echo "\n========================================"
    echo "[*] INITIATING RECOVERY FOR YEAR: $year"
    echo "========================================"

    cd /home/greenc/noisbn
    
    echo "\n[*] Phase 1: Reconciling SIM records ($year, Target Months: $rec_months)..."
    /home/greenc/noisbn/reconcile.py -m $rec_months -y $year -t sim
    /home/greenc/noisbn/refactor.py

    echo "\n[*] Phase 2: Reconciling BOOK records ($year, Target Months: $rec_months)..."
    /home/greenc/noisbn/reconcile.py -m $rec_months -y $year -t books
    /home/greenc/noisbn/refactor.py

    echo "\n[*] Phase 3: Rebuilding HTML Dashboards ($year)..."
    cd /home/greenc/toolforge/iabotwatch
    foreach month ( $html_months )
        echo "  -> Generating $year-$month..."
        /home/greenc/toolforge/iabotwatch/makehtml.awk -y $year -m $month
    end
end

echo "\n[✓] ALL OPERATIONS COMPLETED FOR RANGE: $input"
