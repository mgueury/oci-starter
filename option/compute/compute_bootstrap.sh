#!/bin/bash
# compute_java_bootstrap 
#
# Script that is runned once during the setup of a 
# - compute
# - with Java
if [[ -z "$TF_VAR_language" ]]; then
  echo "Missing env variables"
  exit
fi

export ARCH=`rpm --eval '%{_arch}'`
echo "ARCH=$ARCH"

# Disable SELinux
# XXXXXX Since OL8, the service does not start if SELINUX=enforcing XXXXXX
sudo setenforce 0
sudo sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config

# -- App --------------------------------------------------------------------
# Application Specific installation
# Build all app* directories
for APP_DIR in `ls -d app* | sort -g`; do
  if [ -f $APP_DIR/install.sh ]; then
    chmod +x ${APP_DIR}/install.sh
    ${APP_DIR}/install.sh
  fi  
done

# -- app/start.sh -----------------------------------------------------------
for APP_DIR in `ls -d app* | sort -g`; do
  if [ -f $APP_DIR/start.sh ]; then
    # Hardcode the connection to the DB in the start.sh
    if [ "$DB_URL" != "" ]; then
      sed -i "s!##JDBC_URL##!$JDBC_URL!" $APP_DIR/start.sh 
      sed -i "s!##DB_URL##!$DB_URL!" $APP_DIR/start.sh 
    fi  
    sed -i "s!##TF_VAR_java_vm##!$TF_VAR_java_vm!" $APP_DIR/start.sh   
    chmod +x $APP_DIR/start.sh

    # Create an "app.service" that starts when the machine starts.
    cat > /tmp/$APP_DIR.service << EOT
[Unit]
Description=App
After=network.target

[Service]
Type=simple
ExecStart=/home/opc/$APP_DIR/start.sh
TimeoutStartSec=0
User=opc

[Install]
WantedBy=default.target
EOT

    sudo cp /tmp/$APP_DIR.service /etc/systemd/system
    sudo chmod 664 /etc/systemd/system/$APP_DIR.service
    sudo systemctl daemon-reload
    sudo systemctl enable $APP_DIR.service
    sudo systemctl restart $APP_DIR.service
  fi
done  

# -- UI --------------------------------------------------------------------
# Install NGINX
sudo dnf install nginx -y > /tmp/dnf_nginx.log

# Default: location /app/ { proxy_pass http://localhost:8080 }
sudo cp nginx_app.locations /etc/nginx/conf.d/.
if grep -q nginx_app /etc/nginx/nginx.conf; then
  echo "Include nginx_app.locations is already there"
else
    echo "Adding nginx_app.locations"
    sudo awk -i inplace '/404.html/ && !x {print "        include conf.d/nginx_app.locations;"; x=1} 1' /etc/nginx/nginx.conf
fi

# SE Linux (for proxy_pass)
sudo setsebool -P httpd_can_network_connect 1

# Start it
sudo systemctl enable nginx
sudo systemctl restart nginx

if [ -d ui ]; then
  # Copy the index file after the installation of nginx
  sudo cp -r ui/* /usr/share/nginx/html/
fi

# Firewalld
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload

# -- Util -------------------------------------------------------------------
sudo dnf install -y psmisc
