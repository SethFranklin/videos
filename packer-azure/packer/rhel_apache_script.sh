#!/bin/sh

sleep 30 # Waiting for what? Should add check

sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
sudo dnf -y install httpd
echo "<html><body><h1>Hello from RHEL</h1></body></html>" | sudo tee /var/www/html/index.html
sudo systemctl start httpd
sudo systemctl enable httpd
