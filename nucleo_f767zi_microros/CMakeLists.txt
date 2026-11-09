cmake_minimum_required(VERSION 3.20.0)

# The micro-ROS clone (used via west) is NOT packaged as a west module at its
# repo root - its Kconfig/CMake live inside modules/libmicroros. Register that
# directory as an extra Zephyr module, exactly as the module's own sample app
# does (github.com/micro-ROS/micro_ros_zephyr_module, CMakeLists.txt).
list(APPEND ZEPHYR_EXTRA_MODULES
  ${CMAKE_CURRENT_SOURCE_DIR}/../modules/micro_ros_zephyr_module/modules/libmicroros)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(microros_nucleo_f767zi)

target_sources(app PRIVATE
  src/main.c
)
