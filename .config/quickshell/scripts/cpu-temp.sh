#!/bin/bash
awk '{print int($1/1000)}' /sys/class/hwmon/hwmon4/temp1_input
