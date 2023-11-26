# Run as root
wget https://repo.mysql.com//mysql80-community-release-el8-5.noarch.rpm
yum -y install mysql80-community-release-el8-5.noarch.rpm
yum repolist enabled | grep "mysql.*-community.*"
yum module disable mysql
dnf install mysql-community-server -y
groupadd -g 27 -o -r mysql
useradd -r -g mysql -s /bin/false mysql
id mysql
systemctl start mysqld -y

# Open the Firewall
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload

# cat >> /home/opc/.bash_profile << EOF
# EOF

