#!/usr/bin/python

"""
This script checks if the BlueZ DBus interface is accessible. If it isn't,
either BlueZ (or DBus) is not running or crashed. In that case: restart
dbus (+ bluetoothd) and Gyrid.
"""

import dbus
import os
import subprocess
import time

def popen(command):
    envmt = os.environ
    envmt["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:" + \
        "/sbin:/bin"
    process = subprocess.Popen(command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=envmt)

try:
    bus = dbus.SystemBus();
    obj = bus.get_object('org.bluez', '/')
    manager = dbus.Interface(obj, 'org.bluez.Manager')
except:
    #BlueZ (or DBus) not running/crashed.
    popen(["/etc/init.d/gyrid", "stop"])
    time.sleep(11)
    popen(["/etc/init.d/dbus", "restart"]) #Will indirectly restart bluetoothd.
    time.sleep(3)
    popen(["/etc/init.d/gyrid", "start"])
