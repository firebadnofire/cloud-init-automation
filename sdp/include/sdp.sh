#!/bin/bash

echo "##############################################"
echo "SDP SCRIPT HAS STARTED"

# Ensure Go is activated
PATH="/usr/local/go/bin:$PATH"

# Install SDP itself
git clone https://github.com/firebadnofire/secure-dns-proxy.git /home/testuser/sdp
cd /home/testuser/sdp
make
sudo make install
sudo systemctl enable --now secure-dns-proxy.service

echo "##############################################"
echo "CONTROL TESTS"
nslookup google.com 127.0.0.35
nslookup check.archuser.org 127.0.0.35
echo "##############################################"

echo "##############################################"
echo "HTTPS TESTS"
mv /mnt/cidata/https.json /etc/secure-dns-proxy/config.json
sudo systemctl restart secure-dns-proxy.service

nslookup google.com 127.0.0.35
nslookup check.archuser.org 127.0.0.35
nslookup github.com 127.0.0.35
echo "##############################################"

echo "##############################################"
echo "DOT TESTS"
mv /mnt/cidata/dot.json /etc/secure-dns-proxy/config.json
sudo systemctl restart secure-dns-proxy.service

nslookup google.com 127.0.0.35
nslookup check.archuser.org 127.0.0.35
nslookup github.com 127.0.0.35
echo "##############################################"

echo "##############################################"
echo "DOQ TESTS"
mv /mnt/cidata/doq.json /etc/secure-dns-proxy/config.json
sudo systemctl restart secure-dns-proxy.service

nslookup google.com 127.0.0.35
nslookup check.archuser.org 127.0.0.35
nslookup github.com 127.0.0.35
echo "##############################################"

echo "##############################################"
echo "SDP SCRIPT HAS ENDED"
