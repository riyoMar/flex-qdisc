# Flex-Qdisc

Flex-Qdisc is an OpenWrt service that dynamically manages the **CAKE** queue discipline to mitigate bufferbloat. It automatically configures traffic shaping for both egress and ingress traffic based on the user configuration.

---

# Requirements

Before installing Flex-Qdisc, ensure your router meets the following requirements:

- OpenWrt **23.05.5** or later
- Root (SSH) access
- Internet connection
- **sqm-scripts** package installed

## Verify OpenWrt Version

```sh
cat /etc/openwrt_release
```

Example:

```text
DISTRIB_ID='OpenWrt'
DISTRIB_RELEASE='23.05.5'
```

## Verify SQM Scripts

Flex-Qdisc depends on the **sqm-scripts** package. Make sure it is installed before installing Flex-Qdisc.

Check whether it is installed:

```sh
opkg list-installed | grep sqm-scripts
```

Example output:

```text
sqm-scripts - 1.6.0-1
```

If no output is returned, install it:

```sh
opkg update
opkg install sqm-scripts
```

Verify the CAKE QoS script is available:

```sh
ls /usr/lib/sqm/cake.qos
```

If the file exists, your router is ready to install Flex-Qdisc.

---

# Installation

Install the latest version directly from GitHub:

```sh
wget -O - https://raw.githubusercontent.com/riyoMar/flex-qdisc/main/install.sh | sh
```

The installer will:

- Create the required directories.
- Download the latest Flex-Qdisc files.
- Preserve the existing configuration if `/etc/config/flex-qdisc` already exists.
- Set executable permissions for all required scripts.

## Bandwidth limits

Configure the minimum (`download` and `upload`) and maximum (`max_download` and
`max_upload`) rates in `/etc/config/flex-qdisc`, in kbit/s. The maximum defaults
to `0`, which disables that cap. A configured maximum below its corresponding
minimum is treated as equal to the minimum.

The service starts at the minimum rates. `delta_download` and `delta_upload`
control the percentage increase or decrease per interval (default `5`). The
rate increases when measured traffic reaches 90% of the current rate, and
decreases below the configured `safety` threshold (default `70%`).

The following files will be installed:

```text
/etc/config/flex-qdisc
/etc/flex-qdisc/flex-qdisc
/etc/flex-qdisc/stop
/etc/flex-qdisc/remove
/etc/init.d/flex-qdisc
```

---

# Running Flex-Qdisc

Enable the service so it starts automatically at boot:

```sh
service flex-qdisc enable
```

Start the service:

```sh
service flex-qdisc start
```

---

# Verify the Service

## 1. Check the service status

```sh
service flex-qdisc status
```

The service should report that it is **running**.

---

## 2. Verify the Flex-Qdisc process

```sh
ps | grep flex
```

Example output:

```text
root@OpenWrt:~# ps | grep flex
14742 root      1388 S    {flex-qdisc} /bin/sh /etc/flex-qdisc/flex-qdisc phy0-sta0 5 70 4000 4000 10 5 5
22066 root      1372 S    grep flex
```

The first line indicates that the **Flex-Qdisc** service is running.

The second line is the `grep` command itself and can be ignored.

---

## 3. Verify the CAKE queue disciplines

```sh
tc qdisc | grep cake
```

Example output:

```text
root@OpenWrt:~# tc qdisc | grep cake
qdisc cake de04: dev phy0-sta0 root refcnt 2 bandwidth 4Mbit besteffort triple-isolate nonat nowash no-ack-filter split-gso rtt 100ms raw overhead 0
qdisc cake de05: dev ifb4phy0-sta0 root refcnt 2 bandwidth 4Mbit besteffort triple-isolate nonat nowash no-ack-filter split-gso rtt 100ms raw overhead 0
root@OpenWrt:~#
```

This confirms that the **CAKE** queue disciplines have been successfully applied to:

- The WAN interface (`phy0-sta0`) for egress traffic.
- The IFB interface (`ifb4phy0-sta0`) for ingress traffic.

---

# Configuration

The configuration file is located at:

```text
/etc/config/flex-qdisc
```

Modify the configuration as needed.

After making changes, restart the service:

```sh
service flex-qdisc restart
```

---

# Available Commands

Display all supported service commands:

```sh
service flex-qdisc
```

Typical output:

```text
start
stop
restart
reload
enable
disable
status
remove
```

---

# Updating

To update Flex-Qdisc to the latest version, simply run the installer again:

```sh
wget -O - https://raw.githubusercontent.com/riyoMar/flex-qdisc/main/install.sh | sh
```

Program files will be updated while preserving your existing configuration.

---

# Uninstall

To completely remove Flex-Qdisc:

```sh
service flex-qdisc remove
```

The uninstall process will:

- Stop the running service.
- Remove all installed Flex-Qdisc scripts.
- Remove the init service.
- Remove temporary runtime files.
- Remove Flex-Qdisc installation files.

---

# Project Structure

```text
/etc/
├── config/
│   └── flex-qdisc
├── flex-qdisc/
│   ├── flex-qdisc
│   ├── stop
│   └── remove
└── init.d/
    └── flex-qdisc
```