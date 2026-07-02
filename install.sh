#!/bin/sh

REPO="https://raw.githubusercontent.com/riyoMar/flex-qdisc/main"

echo "Installing Flex-Qdisc..."

# Create directories
mkdir -p /etc/config
mkdir -p /etc/flex-qdisc
mkdir -p /etc/init.d

# Install configuration only if it doesn't exist
if [ ! -f /etc/config/flex-qdisc ]; then
    wget -O /etc/config/flex-qdisc \
        "$REPO/etc/config/flex-qdisc.sh"
else
    echo "Configuration already exists. Skipping."
fi

# Download application scripts
wget -O /etc/flex-qdisc/flex-qdisc \
    "$REPO/etc/flex-qdisc/flex-qdisc.sh"

wget -O /etc/flex-qdisc/stop \
    "$REPO/etc/flex-qdisc/stop.sh"

wget -O /etc/flex-qdisc/remove \
    "$REPO/etc/flex-qdisc/remove.sh"

# Download init script
wget -O /etc/init.d/flex-qdisc \
    "$REPO/etc/init.d/flex-qdisc.sh"

# Make scripts executable
chmod +x /etc/flex-qdisc/flex-qdisc
chmod +x /etc/flex-qdisc/stop
chmod +x /etc/flex-qdisc/remove
chmod +x /etc/init.d/flex-qdisc

echo "Installation completed!"
echo
echo "Try \"service flex-qdisc\" for more options!"