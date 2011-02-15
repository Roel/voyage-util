#!/bin/bash

exit_on_fail() {
    #Exit if previous command was unsuccessful.
    if [ $? != 0 ]; then

        #Disable swap
        if [ -f $MOUNTPOINT/swap ]; then
            swapoff $MOUNTPOINT/swap
        fi

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
        DATAPATH="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        LASTEXDIR="`ls -d1 $(hostname)-* | tail -n 1`"

        #Copy last existing directory to new directory using
        #hard links.
        if [ "$LASTEXDIR" != "" ]; then
            cp -al $LASTEXDIR $DATAPATH
            RSYNCLINKS="--link-dest=$MOUNTPOINT/$LASTEXDIR"
        else
            mkdir $DATAPATH
            RSYNCLINKS=""
        fi

        #Rsync the log directory on the device with the new
        #directory.
        rsync -a $RSYNCLINKS --delete "/var/log/gyrid/" $DATAPATH
    fi
}

temporary_usb() {
    #Do not interact with temporary USB drive through cron.
    if [ "$1" != "cron" ]; then
        #Create log directory on USB device.
        DATADIR="`hostname`-`date +%Y%m%d-%H%M-%Z`"
        export DATAPATH=$MOUNTPOINT/$DATADIR
        mkdir $DATAPATH

        #Write device uptime to meta.txt
        echo -ne "Uptime:\n`uptime`\n\n" >> $DATAPATH/meta.txt

        #Copy over the logs.
        mkdir -p $DATAPATH/original_logs/var_log
        mkdir -p $DATAPATH/original_logs/etc
        mkdir -p $DATAPATH/merged_logs
        rsync -a --copy-links /var/log/ $DATAPATH/original_logs/var_log
        rsync -a --copy-links /etc/ $DATAPATH/original_logs/etc

        #Merge the logs.
        for i in `ls -1 $DATAPATH/original_logs/var_log/gyrid | grep -E "([0-9A-F]){12}"`; do
            mkdir -p $DATAPATH/merged_logs/$i
            cd $DATAPATH/original_logs/var_log/gyrid/$i

                lines=`/usr/local/sbin/gyrid-unzip.py $DATAPATH/merged_logs/$i`

                cd $DATAPATH/merged_logs/$i
                    if [ -f scan.log ]; then
                        sort -T $MOUNTPOINT scan.log -o scan.log
                        lines_scan=`echo $lines | awk '{print $1}'`
                        uniq_macs=`echo $lines | awk '{print $3}'`
                        mv scan.log ../`hostname`-$i-scan.log
                    else
                        lines_scan=0
                        uniq_macs=0
                    fi

                    if [ -f rssi.log ]; then
                        sort -T $MOUNTPOINT rssi.log -o rssi.log
                        lines_rssi=`echo $lines | awk '{print $2}'`
                        mv rssi.log ../`hostname`-$i-rssi.log
                    else
                        lines_rssi=0
                    fi

            rm -r $DATAPATH/merged_logs/$i

            #Write useful statistics to meta.txt
            echo -ne "Sensor $i:\n" >> $DATAPATH/meta.txt
            echo -ne "  Number of loglines in scan.log: $lines_scan\n" >> $DATAPATH/meta.txt
            echo -ne "  Number of loglines in rssi.log: $lines_rssi\n" >> $DATAPATH/meta.txt
            echo -ne "  Number of unique MAC-addresses: $uniq_macs\n\n" >> $DATAPATH/meta.txt
        done

        #Write package versions to packages.txt
        dpkg-query -W -f='${Package}: ${Version}\n ${Status}\n\n' | grep -E ': [^ ]+$' > $DATAPATH/original_logs/packages.txt

    fi
}

#Continue only if there is a USB drive attached.
if [ -e /dev/usbstick ]; then

    #Continue only if no USB drive has been mounted yet.
    if [ `grep usbstick /proc/mounts | wc -l` -eq 0 ]; then

        #Set variables
        export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        export MOUNTPOINT="/mnt/usbstick"

        #Try to mount the USB drive as ext3.
        mount -t ext3 /dev/usbstick $MOUNTPOINT

        if [ $? == 0 ]; then
            #Mount successful

            #Enable swap
            if [ -f $MOUNTPOINT/swap ]; then
                mkswap $MOUNTPOINT/swap
                swapon $MOUNTPOINT/swap
            fi

            privileged_usb $1
            permanent_usb $1

        else
            #Mount unsuccessful, try mounting with different filesystem.
            mount -t auto /dev/usbstick $MOUNTPOINT

            if [ $? == 0 ]; then
                #Mount successful

                #Enable swap
                if [ -f $MOUNTPOINT/swap ]; then
                    mkswap $MOUNTPOINT/swap
                    swapon $MOUNTPOINT/swap
                fi

                privileged_usb $1
                temporary_usb $1

            fi
        fi

        #Disable swap
        if [ -f $MOUNTPOINT/swap ]; then
            swapoff $MOUNTPOINT/swap
        fi

        #Unmount the USB drive.
        umount -l /dev/usbstick
    fi
fi
