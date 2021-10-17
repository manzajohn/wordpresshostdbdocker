#!/bin/bash
#* wait until efs mount is finished
sleep 2m
#* update the instnce
sudo yum update -y
sudo yum install git -y 
#* install docker
sudo yum install -y docker
#* let it be run without sudo
sudo usermod -a -G docker ec2-user
#* start docker engine
sudo service docker start
sudo chkconfig docker on
#* install docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m` | sudo tee /usr/local/bin/docker-compose > /dev/null
#* make it executable
sudo chmod +x /usr/local/bin/docker-compose
#* link docker-compose with bin folder so it can be called globally
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

sudo groupadd -f docker-compose
#* give it permission to work without sudo
sudo usermod -a -G docker-compose ec2-user
#* run docker-compose.yaml
sudo git clone -b sbg https://github.com/manzajohn/wordpressdocker.git /home/ec2-user/wordpress-docker
sudo docker-compose -f /home/ec2-user/wordpress-docker/docker-compose.yaml up --build -d


db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_RDS=${db_RDS}

#install apache server and mysql client
yum install -y httpd

#first enable php7.xx from  amazon-linux-extra and install it

amazon-linux-extras enable php7.4
yum clean metadata
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel}
#install imagick extension
yum -y install gcc ImageMagick ImageMagick-devel ImageMagick-perl
pecl install imagick
chmod 755 /usr/lib64/php/modules/imagick.so
cat <<EOF >>/etc/php.d/20-imagick.ini
extension=imagick
EOF

systemctl restart php-fpm.service

systemctl start  httpd


# Change OWNER and permission of directory /var/www
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Download wordpress package and extract
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/


# Create wordpress configuration file and update database value
cd /var/www/html
cp wp-config-sample.php wp-config.php

sed -i "s/database_name_here/$db_name/g" wp-config.php
sed -i "s/username_here/$db_username/g" wp-config.php
sed -i "s/password_here/$db_user_password/g" wp-config.php
sed -i "s/localhost/$db_RDS/g" wp-config.php
cat <<EOF >>/var/www/html/wp-config.php
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
EOF

# Change permission of /var/www/html/
chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html

#  enable .htaccess files in Apache config using sed command
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf

#Make apache and mysql to autostart and restart apache
systemctl enable  httpd.service
systemctl restart httpd.service
