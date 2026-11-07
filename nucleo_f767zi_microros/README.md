# micro-ROS demo application for NUCLEO-F767ZI on Zephyr

A Zephyr application (this folder is also a **west manifest repository**) that runs a
micro-ROS node over the board's **integrated Ethernet, using UDP transport**.

- Publishes `std_msgs/msg/Int32` on `/zephyr_heartbeat` every 1000 ms (green user LED blinks).
- Subscribes to `std_msgs/msg/Bool` on `/zephyr_led_cmd` (blue user LED toggles on each message).
- Waits for the micro-ROS agent at `CONFIG_MICROROS_AGENT_IP:CONFIG_MICROROS_AGENT_PORT`
  and retries until it is reachable.
- Gets its IP address via DHCP.

## Repository layout

```
nucleo_f767zi_microros/
  |- CMakeLists.txt          # Zephyr application build script
  |- prj.conf                # Kconfig (micro-ROS, transport, networking)
  |- west.yml                # west manifest: pulls Zephyr v4.1.0 + micro-ROS module
  |- src/main.c              # demo application
```

After `west init`/`west update`, the workspace contains `zephyr/`,
`modules/libmicroros` deps of Zephyr and `modules/micro_ros_zephyr_module/`.

## Configuring the agent address

Edit `prj.conf` before building:

```ini
CONFIG_MICROROS_AGENT_IP="192.168.1.100"   # <- your Raspberry Pi IP
CONFIG_MICROROS_AGENT_PORT="8888"          # <- the UDP port the agent listens on
```

The board obtains its own address by DHCP. For a static address instead, replace
`CONFIG_NET_DHCPV4=y` with the static-IP block in the Networking section of `prj.conf`.

## Building (WSL2 on Windows is recommended)

The micro-ROS client library is built with `make`, `colcon` and Python - run the build
inside **WSL2** (the `micro_ros_zephyr_module` README itself used a Linux docker image).

### 1. WSL + toolchain, one-time setup

Windows side (PowerShell):

```powershell
wsl --install -d Ubuntu-24.04
```

Inside WSL:

```bash
sudo apt update && sudo apt install -y build-essential python3-pip python3-venv git wget xxd
pip3 install --break-system-packages catkin_pkg lark-parser empy colcon-common-extensions west
```

Zephyr SDK (provides the `arm-zephyr-eabi` toolchain):

```bash
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.9/zephyr-sdk-0.16.9_linux-x86_64.tar.xz
tar xzf zephyr-sdk-0.16.9_linux-x86_64.tar.xz
cd zephyr-sdk-0.16.9 && ./zephyr-sdk-0.16.9-setup.sh -c
```

### 2. Initialize the workspace and build

```bash
cd /mnt/d/Programming/ROS2/nucleo_f767zi_microros
west init -l .       # creates .west workspace in this folder (source stays where it is)
west update          # clones zephyr + all deps + micro_ros_zephyr_module
pip3 install -r zephyr/scripts/requirements.txt

export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=~/zephyr-sdk-0.16.9

west build -b nucleo_f767zi -p always .
```

If the micro-ROS module is not auto-discovered on your west version, add it explicitly:

```bash
west build -b nucleo_f767zi -p always . -- \
  -DZEPHYR_EXTRA_MODULES=$PWD/../modules/micro_ros_zephyr_module/modules/libmicroros
```

### 3. Flashing

`west flash` requires STM32CubeProgrammer in PATH (default runner for this board). The
easiest mix on Windows: build in WSL, flash from Windows with STM32CubeProgrammer CLI:

```powershell
STM32_Programmer_CLI -c port=SWD mode=NORMAL -w D:\Programming\ROS2\nucleo_f767zi_microros\build\zephyr\zephyr.hex -v -g
```

(or install STM32CubeProgrammer inside WSL2 and just run `west flash`; OpenOCD/J-Link
runners also exist on this board).

### 4. Run

1. Connect the RJ45 to the same switch/router as the Pi.
2. Start the agent on the Pi (see `../raspberry_pi_agent/README.md`).
3. Reset the board. The console (ST-LINK VCP, USART3 @115200) prints agent/address info.
   A blinking green LED (LD1) means "publishing".

## Test from the Pi

```bash
docker exec microros-agent ros2 topic list
# should show /zephyr_heartbeat and /zephyr_led_cmd
docker exec microros-agent ros2 topic echo /zephyr_heartbeat
# toggle the blue LED from the Pi:
docker exec microros-agent ros2 topic pub --once /zephyr_led_cmd std_msgs/msg/Bool "{data: true}"
```

## Serial transport fallback (optional)

If you cannot use Ethernet, switch the transport in `prj.conf`:

```ini
CONFIG_MICROROS_TRANSPORT_SERIAL=y      # instead of UDP, also remove CONFIG_MICROROS_TRANSPORT_UDP=y
CONFIG_MICROROS_SERIAL_PORT="1"        # see module Kconfig; "2" = USART6 on the ST Zio/Arduino header
```

and run the agent with `serial --dev <tty>` instead of `udp4`. Note: with serial, `micro-ROS`
framing is required (the Zephyr module's serial transports handle this via
`MICRO_ROS_FRAMING_REQUIRED`).

## Known limitations

- The micro-ROS library is built as an ExternalProject on first build; a `make`/`colcon`
  sub-build failure most often means missing Python deps (step 1) or a Windows host build.
- Board rev. with SoC marking A has unstable Ethernet (STM32 F767ZI erratum #26519 in Zephyr).
- This module's Kconfig resource counters (`CONFIG_MICROROS_PUBLISHERS` etc.) are `string`
  typed oddities; leave the defaults unless you add more endpoints than the demo uses.
