#!/usr/bin/python

"""
This script checks if the BlueZ DBus interface is accessible. If it isn't,
either BlueZ (or DBus) is not running or crashed. In that case: restart
dbus (+ bluetoothd) and Gyrid.
"""

import dbus
import os
import subprocess

def popen(command):
    environment = os.environ
    environment["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    try:
        process = subprocess.Popen(command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=environment)

        output, errors = process.communicate()
    except:
        #Something bad happened.
        pass
    else:
        if process.returncode:
            #Something bad happened.
            pass

try:
    bus = dbus.SystemBus();
    obj = bus.get_object('org.bluez', '/')
    manager = dbus.Interface(obj, 'org.bluez.Manager')
except:
    #BlueZ (or DBus) not running/crashed.
    popen(["/etc/init.d/dbus", "restart"]) #Will indirectly restart bluetoothd.
    popen(["/etc/init.d/gyrid", "restart"])
