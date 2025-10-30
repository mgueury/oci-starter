#!/usr/bin/env bash
#
if [ -f starter/starter.sh ]; then
  starter/starter.sh $@
else
  # Maybe in PATH ? 
  starter.sh $@
fi  
exit ${PIPESTATUS[0]}
