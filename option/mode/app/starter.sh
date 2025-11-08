#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/..

STARTER_DIR=".starter"
if [ -f $STARTER_DIR/starter.sh ]; then
  echo "Copying the source files to: starter"
  rsync app -av $STARTER_DIR/src/app/ .
  if [ -d db ]; then
    rsync db -av $STARTER_DIR/src/db/ .
  fi
  if [ -f terraform.tfvars ]; then
    cp terraform.tfvars $STARTER_DIR
  fi
  if [ -f done.sh ]; then
    cp done.sh $STARTER_DIR
  fi
  # cp done.txt starter/.
  $STARTER_DIR/starter.sh $@
else
  echo "Error: starter directory not present"
fi  
exit ${PIPESTATUS[0]}
