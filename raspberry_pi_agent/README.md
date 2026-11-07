# micro-ROS agent + ROS 2 on Raspberry Pi 3B+

The Pi hosts the **micro-ROS agent**: the bridge that speaks the micro-ROS (XRCE-DDS)
protocol with the Nucleo (UDP over Ethernet, port 8888) and switches to plain ROS 2
DDS on the other side, so the Nucleo appears as an ordinary node in the ROS 2 graph.

```
ros2 CLI (Docker, host net)  <--DDS-->  micro-ROS agent (Docker, UDP:8888)  <--UDP-->  Nucleo F767ZI
```

## 1. Prepare the Pi (one-time)

1. Flash a **64-bit** OS image (Raspberry Pi OS 64-bit or Ubuntu Server 24.04) - 32-bit
   images are not supported by the arm64 agent image.
2. Connect the Pi's Ethernet to the same switch/LAN as the Nucleo.
3. Install Docker:

   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER
   # re-login afterwards
   ```

4. Note the Pi's IP address - the Nucleo firmware must point at it:

   ```bash
   hostname -I
   ```

   Put that value into the Nucleo project's `prj.conf`
   (`CONFIG_MICROROS_AGENT_IP="..."`).

## 2. Start the agent

Either with compose (recommended, survives reboots):

```bash
cd raspberry_pi_agent   # copy this folder onto the Pi
docker compose up -d
```

or with the helper script (`chmod +x run-agent.sh` first, then `./run-agent.sh`).

Equivalent one-liner (no compose file needed):

```bash
docker run -d --name microros-agent --restart unless-stopped --net=host --privileged \
  -v /dev:/dev microros/micro-ros-agent:rolling udp4 --port 8888 -v6
```

The `microros/micro-ros-agent:rolling` image is published for `linux/amd64` and
`linux/arm64`, so it runs directly on the Pi 3B+.

## 3. Check it

```bash
docker logs -f microros-agent
```

With the agent alone it says it is listening (`CLI ... port 8888`). Once the Nucleo
connects, you will see session/client activity lines.

## 4. Use it: ros2 CLI inside a container

The agent image itself contains ROS 2, so the quickest tool is:

```bash
docker exec -it microros-agent bash -lc "ros2 topic list"
# expect:
#   /zephyr_heartbeat
#   /zephyr_led_cmd
#   /parameters
```

For a full ROS 2 environment (rqt, etc.) run a desktop image, also on the host network:

```bash
docker run -it --rm --network host osrf/ros:humble-desktop bash
# inside the container:
source /opt/ros/humble/setup.bash
ros2 topic list
ros2 topic echo /zephyr_heartbeat
# blink the blue LED while watching the board:
ros2 topic pub --once /zephyr_led_cmd std_msgs/msg/Bool "{data: true}"
```

> The Pi CPU is slow - first pulls/runs take a while, `ros2 topic pub -r 10` is plenty
> for demos (leave `-r` default of 1 Hz for the LED command).

## 5. Notes & troubleshooting

- **ROS_DOMAIN_ID** must match on both ends (default `0`). If you change it, export
  `ROS_DOMAIN_ID=<id>` in the agent service (`environment:` in docker-compose) and in
  every ros2 test container.
- **No topics?** Check that the Nucleo's `CONFIG_MICROROS_AGENT_IP` is this Pi's IP,
  port `8888`, that both are on the same subnet, and that no firewall blocks UDP 8888
  (`sudo netstat -lu | grep 8888` on the Pi should show the listener).
- **Serial instead of UDP (alternative)**: run the agent with
  `serial --dev /dev/ttyACM0 -v6` inside a container that mounts `/dev`
  (`--privileged -v /dev:/dev`). Then the Nucleo must be switched to the serial
  transport (see the Nucleo README). UDP is the default here - it needs no USB cable.
- **After reboots**: the compose service has `restart: unless-stopped`, so the agent
  comes back automatically. The Nucleo retries pinging until the agent is there.
- **RMW**: default Fast DDS everywhere in this setup; don't mix in a Cyclone DDS-only
  config unless you set `RMW_IMPLEMENTATION` consistently.
