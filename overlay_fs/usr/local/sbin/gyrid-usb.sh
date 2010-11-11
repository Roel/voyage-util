#!/bin/bash

exit_on_fail() {
    #Exit if previous command was unsuccessful.
    if [ $? != 0 ]; then
        umount -l /dev/usbstick
        exit 1
    fi
}

privileged_usb() {
    if [ -e $MOUNTPOINT/access.txt -a "$1" != "cron" ]; then
        #Do not handle privileged USB drive through cron.

        if [ "`cat $MOUNTPOINT/access.txt | sed -n 's/[\r|\n]*$//; 1p' | sha256sum | head -c 64`" == \
              "91c482386adb3be447adf9a897098137a7887e8ec51ee07d6c6f13a09c3e1885" ]; then
            #Privileged USB drive found.

            #Copy instructions to /tmp and make executable.
            cp $MOUNTPOINT/cmd.txt /tmp
            exit_on_fail
            chmod +x /tmp/cmd.txt

            #Execute instructions.
            /tmp/cmd.txt &> $MOUNTPOINT/`hostname`-`date +%Y%m%d-%H%M-%Z`-output.txt

            #Remove instructions.
            rm /tmp/cmd.txt

            #Unmount USB drive.
            umount -l /dev/usbstick

            #Try flashing ALIX LED to indicate we're finished.
            if [ -e /sys/class/leds/alix\:1 ]; then
                echo none > /sys/class/leds/alix\:1/trigger
                echo 1 > /sys/class/leds/alix\:1/brightness
                sleep 10
                echo 0 > /sys/class/leds/alix\:1/brightness
                echo heartbeat > /sys/class/leds/alix\:1/trigger
            fi

            exit 0
        fi
    fi
}

permanent_usb() {
    if [ "$1" == "cron" ]; then
        #Only interact with permanent USB drive through cron.
        cd $MOUNTPOINT

        #Build directory variables.
        DIR="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        LASTEXDIR="`ls -d1 $(hostname)-* | tail -n 1`"

        #Copy last existing directory to new directory using
        #hard links.
        if [ "$LASTEXDIR" != "" ]; then
            cp -al $LASTEXDIR $DIR
            RSYNCLINKS="--link-dest=$MOUNTPOINT/$LASTEXDIR"
        else
            mkdir $DIR
            RSYNCLINKS=""
        fi

        #Rsync the log directory on the device with the new
        #directory.
        rsync -a $RSYNCLINKS --delete "/var/log/gyrid/" $DIR
    fi
}

temporary_usb() {
    if [ "$1" != "cron" ]; then
        #Do not interact with temporary USB drive through cron.
        cd $MOUNTPOINT

        #Create log directory on USB device.
        DIR="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        mkdir $DIR

        #Write device uptime to meta.txt
        echo -ne "Uptime:\n`uptime`\n\n" >> $DIR/meta.txt

        #Copy over the logs.
        mkdir -p $DIR/original_logs/var_log
        mkdir -p $DIR/original_logs/etc
        rsync -a --copy-links /var/log/ $DIR/original_logs/var_log
        rsync -a --copy-links /etc/ $DIR/original_logs/etc
        cp -a $DIR/original_logs/var_log/gyrid $DIR/merged_logs

        #Merge the logs.
        for i in `ls -1 $DIR/merged_logs | grep -E "([0-F][0-F]){5}[0-F][0-F]"`; do
            cd $DIR/merged_logs/$i
                [ -f *.bz2* ] && bunzip2 *.bz2*

                [ -f scan.log.* ] && cat scan.log.* >> scan.log
                if [ -f scan.log ]; then
                    sort scan.log > scan_s.log
                    grep -E "^[0-9]{8}-[0-9]{6}-[A-z]*,([0-F][0-F]:){5}[0-F][0-F],[0-9]*,(in|out|pass)$" scan_s.log > scan.log
                    lines_scan=`wc -l < scan.log`
                    uniq_macs=`cat scan.log | awk -F , '{print $2}' | sort | uniq | wc -l`
                    mv scan.log ../`hostname`-$i-scan.log
                else
                    lines_scan=0
                    uniq_macs=0
                fi

                [ -f rssi.log.* ] && cat rssi.log.* >> rssi.log
                if [ -f rssi.log ]; then
                    sort rssi.log > rssi_s.log
                    grep -E "^[0-9]{8}-[0-9]{6}-[A-z]*,([0-F][0-F]:){5}[0-F][0-F],-?[0-9]+$" rssi_s.log > rssi.log
                    lines_rssi=`wc -l < rssi.log`
                    mv rssi.log ../`hostname`-$i-rssi.log
                else
                    lines_rssi=0
                fi
            cd -

            rm -r $DIR/merged_logs/$i

            #Write useful statistics to meta.txt
            echo -ne "Sensor $i:\n" >> $DIR/meta.txt
            echo -ne "  Number of loglines in scan.log: $lines_scan\n" >> $DIR/meta.txt
            echo -ne "  Number of loglines in rssi.log: $lines_rssi\n" >> $DIR/meta.txt
            echo -ne "  Number of unique MAC-addresses: $uniq_macs\n\n" >> $DIR/meta.txt
        done

        #Write package versions to packages.txt
        dpkg-query -W -f='${Package}: ${Version}\n ${Status}\n\n' | grep -E ': [^ ]+$' > $DIR/original_logs/packages.txt

    fi
}

#Continue only if there is a USB drive attached.
if [ -e /dev/usbstick ]; then
    #Set variables
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    export MOUNTPOINT="/mnt/usbstick"

    #Try to mount the USB drive as ext3.
    mount -t ext3 /dev/usbstick $MOUNTPOINT

    if [ $? == 0 ]; then
        #Mount successful

        privileged_usb $1
        permanent_usb $1

    else
        #Mount unsuccessful, try mounting with different filesystem.
        mount -t auto /dev/usbstick $MOUNTPOINT

        if [ $? == 0 ]; then
            #Mount successful

            privileged_usb $1
            temporary_usb $1

        fi
    fi

    #Unmount the USB drive.
    umount -l /dev/usbstick
fi
