#!/usr/local/bin/awk -bE

@include "library"

BEGIN {

  IGNORECASE = 1

  for(z = 1; z <= 2; z++) {
    ps = sys2var(Exe["ps"] " aux | " Exe["grep"] " iabotwatch.csh | " Exe["grep"] " -v grep")
    for(i = 1; i <= splitn(ps "\n", a, i); i++) {
      if(a[i] ~ "iabotwatch.csh") 
        exit
    }
  }

  system("(/home/greenc/toolforge/iabotwatch/iabotwatch.csh)&")

}
