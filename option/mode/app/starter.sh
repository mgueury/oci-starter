#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/..

if [ -f starter/starter.sh ]; then
  echo "Copying the source files to: starter"
  rsync app -av starter/src/app/ .
  if [ -d db ]; then
    rsync db -av starter/src/db/ .
  fi
  if [ -f terraform.tfvars ]; then
    cp terraform.tfvars starter/.
  fi
  if [ -f done.sh ]; then
    cp done.sh starter/.
  fi
  # cp done.txt starter/.
  starter/starter.sh $@
else
  echo "Error: starter directory not present"
fi  
exit ${PIPESTATUS[0]}
