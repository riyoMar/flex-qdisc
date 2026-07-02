#!/bin/sh

REPO="https://raw.githubusercontent.com/riyoMar/flex-qdisc/main"

echo "Installing Flex-Qdisc..."

# Create directories
mkdir -p /etc/config
mkdir -p /etc/flex-qdisc
mkdir -p /etc/init.d

# Download files
wget -O /etc/config/flex-qdisc \
    "$REPO/etc/config/flex-qdisc.sh"

wget -O /etc/flex-qdisc/stop \
    "$REPO/etc/flex-qdisc/stop.sh"

wget -O /etc/flex-qdisc/remove \
    "$REPO/etc/flex-qdisc/remove.sh"

wget -O /etc/init.d/flex-qdisc \
    "$REPO/etc/init.d/flex-qdisc.sh"

# Make executable
chmod +x /etc/flex-qdisc/stop
chmod +x /etc/flex-qdisc/remove
chmod +x /etc/init.d/flex-qdisc

echo "Installation completed."
echo "Run: /etc/init.d/flex-qdisc start"