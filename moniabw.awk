#!/usr/local/bin/awk -bE

@include "library"

BEGIN {

  IGNORECASE = 1

  for(z = 1; z <= 2; z++) {
    ps = sys2var(Exe["ps"] " aux | " Exe["grep"] " iabw-stream.csh | " Exe["grep"] " -v grep")
    for(i = 1; i <= splitn(ps "\n", a, i); i++) {
      if(a[i] ~ "iabw-stream.csh") 
        exit
    }
  }

  # Completely detach the wrapper from cron so it survives indefinitely
  system("nohup /home/greenc/toolforge/iabotwatch/iabw-stream.csh > /dev/null 2>&1 &")
  
}
