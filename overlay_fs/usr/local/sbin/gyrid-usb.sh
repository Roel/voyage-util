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

            #Check for options.
            quiet=false
            readout=false
            for opt in `sed -n '/^##/ { s/##//p }' /tmp/cmd.txt`; do
                case "$opt" in
                    "quiet")
                        quiet=true
                        ;;
                    "readout")
                        readout=true
                        ;;
                esac
            done

            #Execute instructions.
            if [ $readout == true ]; then
                temporary_usb
            fi

            if [ $quiet == true ]; then
                /tmp/cmd.txt &> /dev/null
            else
                /tmp/cmd.txt &> $MOUNTPOINT/`hostname`-`date +%Y%m%d-%H%M-%Z`-output.txt
            fi

            #Remove instructions.
            rm /tmp/cmd.txt

            #Unmount USB drive.
            umount -l /dev/usbstick

            exit 0
        fi
    fi
}

permanent_usb() {
    if [ "$1" == "cron" ]; then
        #Only interact with permanent USB drive through cron.
        cd $MOUNTPOINT

        #Build directory variables.
        DATADIR="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        LASTEXDIR="`ls -d1 $(hostname)-* | tail -n 1`"

        #Copy last existing directory to new directory using
        #hard links.
        if [ "$LASTEXDIR" != "" ]; then
            cp -al $LASTEXDIR $DATADIR
            RSYNCLINKS="--link-dest=$MOUNTPOINT/$LASTEXDIR"
        else
            mkdir $DATADIR
            RSYNCLINKS=""
        fi

        #Rsync the log directory on the device with the new
        #directory.
        rsync -a $RSYNCLINKS --delete "/var/log/gyrid/" $DATADIR
    fi
}

temporary_usb() {
    if [ "$1" != "cron" ]; then
        #Do not interact with temporary USB drive through cron.
        cd $MOUNTPOINT

        #Create log directory on USB device.
        export DATADIR="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        mkdir $DATADIR

        #Write device uptime to meta.txt
        echo -ne "Uptime:\n`uptime`\n\n" >> $DATADIR/meta.txt

        #Copy over the logs.
        mkdir -p $DATADIR/original_logs/var_log
        mkdir -p $DATADIR/original_logs/etc
        rsync -a --copy-links /var/log/ $DATADIR/original_logs/var_log
        rsync -a --copy-links /etc/ $DATADIR/original_logs/etc
        cp -a $DATADIR/original_logs/var_log/gyrid $DATADIR/merged_logs

        #Merge the logs.
        for i in `ls -1 $DATADIR/merged_logs | grep -E "([0-9A-F][0-9A-F]){5}[0-9A-F][0-9A-F]"`; do
            cd $DATADIR/merged_logs/$i
                [ `ls -1 *.bz2* | wc -l` -gt 0 ] && bunzip2 *.bz2*

                [ `ls -1 scan.log.* | wc -l` -gt 0 ] && cat scan.log.* >> scan.log
                if [ -f scan.log ]; then
                    sort scan.log > scan_s.log
                    grep -aE "^[0-9]{8}-[0-9]{6}-[A-Za-z]*,([0-9A-F][0-9A-F]:){5}[0-9A-F][0-9A-F],[0-9]*,(in|out|pass)$" scan_s.log > scan.log
                    lines_scan=`wc -l < scan.log`
                    uniq_macs=`cat scan.log | awk -F , '{print $2}' | sort | uniq | wc -l`
                    mv scan.log ../`hostname`-$i-scan.log
                else
                    lines_scan=0
                    uniq_macs=0
                fi

                [ `ls -1 rssi.log.* | wc -l` -gt 0 ] && cat rssi.log.* >> rssi.log
                if [ -f rssi.log ]; then
                    sort rssi.log > rssi_s.log
                    grep -aE "^[0-9]{8}-[0-9]{6}-[A-Za-z]*,([0-9A-F][0-9A-F]:){5}[0-9A-F][0-9A-F],-?[0-9]+$" rssi_s.log > rssi.log
                    lines_rssi=`wc -l < rssi.log`
                    mv rssi.log ../`hostname`-$i-rssi.log
                else
                    lines_rssi=0
                fi
            cd -

            rm -r $DATADIR/merged_logs/$i

            #Write useful statistics to meta.txt
            echo -ne "Sensor $i:\n" >> $DATADIR/meta.txt
            echo -ne "  Number of loglines in scan.log: $lines_scan\n" >> $DATADIR/meta.txt
            echo -ne "  Number of loglines in rssi.log: $lines_rssi\n" >> $DATADIR/meta.txt
            echo -ne "  Number of unique MAC-addresses: $uniq_macs\n\n" >> $DATADIR/meta.txt
        done

        #Write package versions to packages.txt
        dpkg-query -W -f='${Package}: ${Version}\n ${Status}\n\n' | grep -E ': [^ ]+$' > $DATADIR/original_logs/packages.txt

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
