#!/usr/bin/env bash
# Start the micro-ROS agent with the UDP transport (no docker compose needed).
# Equivalent to: docker compose up
set -e

docker run -d \
  --name microros-agent \
  --restart unless-stopped \
  --net=host \
  --privileged \
  -v /dev:/dev \
  microros/micro-ros-agent:rolling \
  udp4 --port 8888 -v6

echo "Agent running (container: microros-agent). Logs: docker logs -f microros-agent"
