#!/usr/bin/env bash
# Build_ui.sh
#
# Compute:
# - build the code 
# - create a $ROOT/compute/ui directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/../../starter.sh env -no-auto
. $BIN_DIR/build_common.sh

build_ui

# Create a self signed certificate for the IP 
if [ "$APIGW_HOSTNAME" = "" ]; then
   if [ ! -f $TARGET_DIR/app/ui/nginx_tls.conf ]; then
      # Nginx config
      mkdir -p $TARGET_DIR/compute/app/ui
      cp nginx_tls.conf $TARGET_DIR/compute/app/ui/.
      cd $TARGET_DIR/compute/app/ui
      file_replace_variables nginx_tls.conf 

      # IP Certificate Request      
      cat > san.cnf << EOF     
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = State
L = City
O = Organization
CN = $BASTION_IP

[req_ext]
subjectAltName = @alt_names

[alt_names]
IP.1 = $BASTION_IP
EOF


      # Generate the key and the chain      
     openssl genrsa -out server.key 2048
     openssl req -new -key server.key -out server.csr -config san.cnf
     openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365 -extensions req_ext -extfile san.cnf
   fi
fi
