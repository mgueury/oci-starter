#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

exit_on_error() {
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo "Success"
  else
    echo "Failed (RESULT=$RESULT)"
    exit $RESULT
  fi  
}

# Install certbot
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
sudo dnf install snapd nginx -y
sudo systemctl enable --now snapd.socket
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Install nginx
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --reload

x=10
while [ $x -gt 0 ]
do
  nslookup $TF_VAR_dns_name
  sudo certbot --agree-tos --nginx --email $CERTIFICATE_EMAIL -d $TF_VAR_dns_name
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo "Success - certbot"
    x=0
  else 
    echo "Cerbot failed - Retrying $x - Waiting 60 secs for the DNS"
    sleep 60  
    x=$(( $x - 1 ))
    if [ $x -eq 0 ]; then
      echo "ERROR"
      exit 1
    fi
  fi
done

# Place the certificate in an OPC directory so that it can be copied via SSH.
mkdir certificate
sudo cp -Lr /etc/letsencrypt/live/$TF_VAR_dns_name /home/opc/tls/certificate
sudo chown -R opc certificate