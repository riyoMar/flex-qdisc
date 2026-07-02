#!/bin/sh

# Create directory
mkdir -p /etc/flex-qdisc

# Install scripts
cp etc/flex-qdisc/stop.sh /etc/flex-qdisc/stop
cp etc/flex-qdisc/remove.sh /etc/flex-qdisc/remove

# Make scripts executable
chmod +x /etc/flex-qdisc/stop
chmod +x /etc/flex-qdisc/remove

# Install config (do not overwrite if it already exists)
[ -f /etc/config/flex-qdisc ] || \
    cp etc/config/flex-qdisc.sh /etc/config/flex-qdisc

# Install init script
cp etc/init.d/flex-qdisc.sh /etc/init.d/flex-qdisc
chmod +x /etc/init.d/flex-qdisc

echo "Flex-Qdisc installed successfully."