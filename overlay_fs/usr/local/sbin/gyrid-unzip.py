#!/usr/bin/python
#-*- coding: utf-8 -*-

import bz2
import glob
import re
import sys

def unzip(regex, filename, output, uniq=None):
    try:
        if 'bz2' in filename:
            fle = bz2.BZ2File(filename, 'r')
        else:
            fle = open(filename, 'r')
    except:
        return 0

    lines = 0
    try:
        for line in fle:
            if regex.match(line):
                if uniq != None:
                    uniq.add(line.split(',')[1])
                output.write(line)
                lines += 1
    except:
        fle.close()
    else:
        fle.close()
    return lines

if len(sys.argv) <= 1:
    sys.exit(1)

output = sys.argv[1].rstrip('/')

scanfiles = glob.glob('scan*')
rssifiles = glob.glob('rssi*')
scan_lines = 0
rssi_lines = 0
uniq_pool = set()

if len(scanfiles) > 0:
    output_scan = open(output + '/scan.log', 'a')
    r = re.compile(r'^[0-9]{8}-[0-9]{6}-[A-Za-z]*,([0-9A-F][0-9A-F]:){5}[0-9A-F][0-9A-F],[0-9]*,(in|out|pass)$')

    for f in glob.glob('scan*'):
        scan_lines += unzip(r, f, output_scan, uniq_pool)

    output_scan.close()

if len(rssifiles) > 0:
    output_rssi = open(output + '/rssi.log', 'a')
    r = re.compile(r'^[0-9]{8}-[0-9]{6}-[A-Za-z]*,([0-9A-F][0-9A-F]:){5}[0-9A-F][0-9A-F],-?[0-9]+$')

    for f in glob.glob('rssi*'):
        rssi_lines += unzip(r, f, output_rssi)

    output_rssi.close()

print "%i %i %i" % (scan_lines, rssi_lines, len(uniq_pool))
