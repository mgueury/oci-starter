#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
. ./env.sh

source myenv/bin/activate
python app.py 2>&1 | tee app.log
