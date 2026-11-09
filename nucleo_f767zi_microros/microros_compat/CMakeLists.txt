# SPDX-License-Identifier: Apache-2.0
#
# Zephyr >= 3.4 relocated the POSIX headers from `include/posix/` to
# `include/zephyr/posix/` (https://github.com/zephyrproject-rtos/zephyr).
# The micro-ROS module's UDP transport still uses the 2022-style
# `#include <posix/sys/socket.h>` (untouched upstream since 2022-12, in
# ALL micro_ros_zephyr_module branches incl. rolling), so on Zephyr 4.1
# compilation of modules/libmicroros/.../microros_transports/udp/* and any
# source including microros_transports.h fails with
#     fatal error: posix/sys/socket.h: No such file or directory
#
# Fix: put `include/zephyr` on the include path as well - then the old-style
# name resolves to the file's new location instead of forking the module.
#
# NOTE on scope: `zephyr_include_directories()` called from an *application*
# CMakeLists only affects the 'app' target, but called from a *module*
# CMakeLists it applies globally (all in-tree Zephyr libraries too). That is
# why this shim exists as its own tiny module and is registered via
# ZEPHYR_EXTRA_MODULES in the application CMakeLists.txt.
zephyr_include_directories(${ZEPHYR_BASE}/include/zephyr)
