# Install the JVM (jdk or graalvm)
install_java

# Install Tomcat
export TOMCAT_HOME=/opt/tomcat

# Create tomcat user, disable login and give rights
# sudo useradd -s /bin/nologin -g opc -d $TOMCAT_HOME tomcat
sudo groupadd tomcat
sudo useradd -g tomcat -d $TOMCAT_HOME tomcat

# Download Tomcat
sudo dnf install -y wget
VER=11.0.13
cd /tmp
sudo mkdir -p /opt/tomcat
wget -nv https://archive.apache.org/dist/tomcat/tomcat-11/v${VER}/bin/apache-tomcat-${VER}.tar.gz
sudo tar -xvf /tmp/apache-tomcat-$VER.tar.gz -C $TOMCAT_HOME --strip-components=1

# Copy the Application and the start script to $TOMCAT_HOME
sudo cp /home/opc/app/starter-1.0.war $TOMCAT_HOME/webapps
sudo mv /home/opc/app/start.sh $TOMCAT_HOME/bin/.
sudo mv /home/opc/app/env.sh $TOMCAT_HOME/bin/.

sudo chown -R tomcat: $TOMCAT_HOME
sudo sh -c "chmod +x $TOMCAT_HOME/bin/*.sh"
cat > /tmp/tomcat.service << EOF 
[Unit]
Description=Apache Tomcat Web Application Container
Wants=network.target
After=network.target

[Service]
Type=forking

ExecStart=$TOMCAT_HOME/bin/start.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh
SuccessExitStatus=143

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/tomcat.service /etc/systemd/system/tomcat.service 

sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat
