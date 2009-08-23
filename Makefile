# Makefile

install:
	# Installing main scripts
	install -m 755 ./*.sh ${DESTDIR}/usr/local/sbin

	install -m 755 voyage.update ${DESTDIR}/usr/local/sbin

	install -m 755 ./overlay_fs/usr/local/sbin/* ${DESTDIR}/usr/local/sbin

#	install -d -m 755 $(DESTDIR)/etc/voyage-profiles
#	install -m 644 voyage-profiles/* $(DESTDIR)/etc/voyage-profiles

	mkdir ${DESTDIR}/etc
	cp -r overlay_fs/etc/* ${DESTDIR}/etc 

	find $(DESTDIR) -name ".svn" -exec rm -rf '{}' '+'
	find $(DESTDIR) -name "*.bak" -exec rm -rf '{}' '+'

	mkdir -p ${DESTDIR}/mnt/usbstick
	
#####################################
# unused
	# Installing sub scripts
	#install -d -m 755 $(DESTDIR)/usr/share/make-live/scripts
	#install -m 755 scripts/* $(DESTDIR)/usr/share/make-live/scripts

	# Installing manpage
	#install -D -m 644 make-live.8 $(DESTDIR)/usr/share/man/man8/make-live.8

	# Installing configuration file
	#install -D -m 644 make-live.default $(DESTDIR)/etc/default/make-live

