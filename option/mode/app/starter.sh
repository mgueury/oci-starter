#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/..

STARTER_DIR=".starter"
if [ -f $STARTER_DIR/starter.sh ]; then
  echo "-- Synchronizing the source files with directory $STARTER_DIR --"
  if [ -d app ]; then
    rsync -av app $STARTER_DIR/src/app
  fi
  if [ -d src ]; then
    rsync -av src $STARTER_DIR/src/app/src
    if [ -f build_app.sh ]; then
      cp build_app.sh $STARTER_DIR/src/app/.
    fi
  fi
  if [ -d db ]; then
    rsync -av db $STARTER_DIR/src/db
  fi
  if [ -f terraform ]; then
    rsync -R terraform $STARTER_DIR/target/app_terraform
    cp -R $STARTER_DIR/target/app_terraform $STARTER_DIR/src/terraform
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
  echo "Error: $STARTER_DIR directory is missing"
fi  
exit ${PIPESTATUS[0]}
