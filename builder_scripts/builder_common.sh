#!/bin/sh
#
# Common functions to be used by build scripts
#
# $Id$

# Crank up error reporting, debugging.
#set -e 
#set -x

fixup_libmap() {
	
}

print_error_pfS() {
	echo
	echo "####################################"
    echo "Something went wrong, check errors!" >&2
	echo "####################################"
	echo
    [ -n "${LOGFILE:-}" ] && \
        echo "Log saved on ${LOGFILE}" >&2
    cat $LOGFILE
    sleep 99999
    kill $$ # NOTE: exit 1 won't work.

}

check_for_clog() {
	if [ ! -d /usr/src/usr.sbin/clog ]; then
		echo "Could not find /usr/src/usr.sbin/clog.  Run cvsup_current.sh first!"
		exit
	fi
}

# Removes NAT_T and other unneeded kernel options from 1.2 images.
fixup_kernel_options() {
	if [ "${PFSENSETAG}" = "RELENG_1_2" ]; then
		echo ">>> Removing unneeded kernel configuration option from 1.2"
		cat /usr/src/sys/i386/conf/pfSense_SMP.${FreeBSD_version} | grep -v "NAT_T" | sed s/ipdivert// > /usr/src/sys/i386/conf/pfSense_SMP.${FreeBSD_version}.tmp
		cat /usr/src/sys/i386/conf/pfSense.${FreeBSD_version} | grep -v "NAT_T" | sed s/ipdivert//  > /usr/src/sys/i386/conf/pfSense.${FreeBSD_version}.tmp
		cat /usr/src/sys/i386/conf/pfSense_wrap.${FreeBSD_version} | grep -v "NAT_T" | sed s/ipdivert// > /usr/src/sys/i386/conf/pfSense_wrap.${FreeBSD_version}.tmp
		cat /usr/src/sys/i386/conf/pfSense_Dev.${FreeBSD_version} | grep -v "NAT_T" | sed s/ipdivert// > /usr/src/sys/i386/conf/pfSense_Dev.${FreeBSD_version}.tmp
		cp /usr/src/sys/i386/conf/pfSense_SMP.${FreeBSD_version}.tmp /usr/src/sys/i386/conf/pfSense_SMP.${FreeBSD_version}
		cp /usr/src/sys/i386/conf/pfSense.${FreeBSD_version}.tmp /usr/src/sys/i386/conf/pfSense.${FreeBSD_version}
		cp /usr/src/sys/i386/conf/pfSense_wrap.${FreeBSD_version}.tmp /usr/src/sys/i386/conf/pfSense_wrap.${FreeBSD_version}
		cp /usr/src/sys/i386/conf/pfSense_Dev.${FreeBSD_version}.tmp /usr/src/sys/i386/conf/pfSense_Dev.${FreeBSD_version}
	fi
}

build_embedded_kernel() {

	# 6.x is picky on destdir=
	touch /boot/loader.conf
	
	mkdir -p /tmp/kernels/wrap/boot/defaults
	mkdir -p /tmp/kernels/wrap/boot/kernel

	mkdir -p $PFSENSEBASEDIR/kernels/

	touch /tmp/kernels/wrap/boot/defaults/loader.conf

	# 6.x is picky on destdir=
	cp /boot/device.hints /tmp/kernels/wrap/boot/
	cp /boot/loader.conf /tmp/kernels/wrap/boot/loader.conf:
	cp /boot/defaults/loader.conf /tmp/kernels/wrap/boot/defaults/loader.conf
	
	# Copy pfSense kernel configuration files over to /usr/src/sys/i386/conf
	cp $BASE_DIR/tools/builder_scripts/conf/pfSense* /usr/src/sys/i386/conf/

	# Remove unneeded kernel options from 1.2
	fixup_kernel_options

	# Build embedded kernel
	echo ">>> Building embedded kernel..."
	rm -f $MAKEOBJDIRPREFIX/usr/home/pfsense/freesbie2/.*kernel*
	unset KERNCONF
	unset KERNELCONF		
	export KERNCONF=pfSense_wrap.${FreeBSD_version}
	unset KERNEL_DESTDIR
	export KERNEL_DESTDIR="/tmp/kernels/wrap"
	freesbie_make buildkernel
	freesbie_make installkernel

	echo -n ">>> Installing kernels to LiveCD area..."
	(cd /tmp/kernels/wrap/boot/ && tar czf $PFSENSEBASEDIR/kernels/kernel_wrap.gz .) 	
	echo -n "."
	chflags -R noschg $PFSENSEBASEDIR/boot/
	(cd $PFSENSEBASEDIR/boot/ && tar xzf $PFSENSEBASEDIR/kernels/kernel_wrap.gz -C $PFSENSEBASEDIR/boot/)
	echo "done."

}

# This routine builds all kernels during the 
# build_iso.sh routines.
build_all_kernels() {

	# 6.x is picky on destdir=
	touch /boot/loader.conf

	# Build extra kernels (embedded, developers edition, etc)
	mkdir -p /tmp/kernels/wrap/boot/kernel
	mkdir -p /tmp/kernels/developers/boot/kernel
	mkdir -p /tmp/kernels/SMP/boot/kernel
	mkdir -p /tmp/kernels/uniprocessor/boot/

	mkdir -p /tmp/kernels/wrap/boot/defaults/
	mkdir -p /tmp/kernels/developers/boot/defaults/
	mkdir -p /tmp/kernels/SMP/boot/defaults/
	mkdir -p /tmp/kernels/uniprocessor/boot/defaults/

	touch /tmp/kernels/wrap/boot/defaults/loader.conf
	touch /tmp/kernels/developers/boot/defaults/loader.conf
	touch  /tmp/kernels/SMP/boot/defaults/loader.conf
	touch  /tmp/kernels/uniprocessor/boot/defaults/loader.conf

	mkdir -p $PFSENSEBASEDIR/boot/kernel

	# 6.x is picky on destdir=	
	cp /boot/device.hints /tmp/kernels/wrap/boot/
	cp /boot/device.hints /tmp/kernels/uniprocessor/boot/
	cp /boot/device.hints /tmp/kernels/SMP/boot/
	cp /boot/device.hints /tmp/kernels/developers/boot/

	cp /boot/defaults/loader.conf /tmp/kernels/wrap/boot/defaults/
	cp /boot/defaults/loader.conf /tmp/kernels/uniprocessor/boot/defaults/
	cp /boot/defaults/loader.conf /tmp/kernels/SMP/boot/defaults/
	cp /boot/defaults/loader.conf /tmp/kernels/developers/boot/defaults/

	# Copy pfSense kernel configuration files over to /usr/src/sys/i386/conf
	cp $BASE_DIR/tools/builder_scripts/conf/pfSense* /usr/src/sys/i386/conf/
	cp $BASE_DIR/tools/builder_scripts/conf/pfSense.6 /usr/src/sys/i386/conf/pfSense_SMP.6
	cp $BASE_DIR/tools/builder_scripts/conf/pfSense.7 /usr/src/sys/i386/conf/pfSense_SMP.7
	echo "" >> /usr/src/sys/i386/conf/pfSense_SMP.6
	echo "" >> /usr/src/sys/i386/conf/pfSense_SMP.7

	# Add SMP and APIC options
	echo "options 		SMP"   >> /usr/src/sys/i386/conf/pfSense_SMP.6
	echo "options 		SMP"   >> /usr/src/sys/i386/conf/pfSense_SMP.7
	echo "device 		apic" >> /usr/src/sys/i386/conf/pfSense_SMP.6
	echo "device 		apic" >> /usr/src/sys/i386/conf/pfSense_SMP.7
	echo "options		ALTQ_NOPCC" >> /usr/src/sys/i386/conf/pfSense_SMP.6
	echo "options		ALTQ_NOPCC" >> /usr/src/sys/i386/conf/pfSense_SMP.7

	# Remove unneeded kernel options from 1.2
	fixup_kernel_options

	# Build uniprocessor kernel
	echo ">>> Building uniprocessor kernel..."
	rm -f $MAKEOBJDIRPREFIX/usr/home/pfsense/freesbie2/.*kernel*
	unset KERNCONF
	unset KERNELCONF
	export KERNCONF=pfSense.${FreeBSD_version}
	unset KERNEL_DESTDIR
	export KERNEL_DESTDIR="/tmp/kernels/uniprocessor"
	freesbie_make buildkernel
	freesbie_make installkernel

	# Build embedded kernel
	echo ">>> Building embedded kernel..."
	rm -f $MAKEOBJDIRPREFIX/usr/home/pfsense/freesbie2/.*kernel*
	unset KERNCONF
	unset KERNELCONF		
	export KERNCONF=pfSense_wrap.${FreeBSD_version}
	unset KERNEL_DESTDIR
	export KERNEL_DESTDIR="/tmp/kernels/wrap"
	freesbie_make buildkernel
	freesbie_make installkernel

	# Build Developers kernel
	echo ">>> Building Developers kernel..."
	rm -f $MAKEOBJDIRPREFIX/usr/home/pfsense/freesbie2/.*kernel*
	unset KERNCONF
	unset KERNELCONF
	export KERNCONF=pfSense_Dev.${FreeBSD_version}
	unset KERNEL_DESTDIR
	export KERNEL_DESTDIR="/tmp/kernels/developers"
	freesbie_make buildkernel
	freesbie_make installkernel
	
	# Build SMP kernel
	echo ">>> Building SMP kernel..."
	rm -f $MAKEOBJDIRPREFIX/usr/home/pfsense/freesbie2/.*kernel*
		
	unset KERNCONF
	unset KERNELCONF		
	export KERNCONF=pfSense_SMP.${FreeBSD_version}
	unset KERNEL_DESTDIR
	export KERNEL_DESTDIR="/tmp/kernels/SMP"
	freesbie_make buildkernel
	freesbie_make installkernel

	# Create area where kernels will be copied on LiveCD
	mkdir -p $PFSENSEBASEDIR/kernels/

	# Nuke symbols
	echo -n ">>> Cleaning up .symbols..."
    if [ -z "${PFSENSE_DEBUG:-}" ]; then
		echo -n "."
		find $PFSENSEBASEDIR/ -name "*.symbols" -exec rm {} \;
		echo -n "."
		find /tmp/kernels -name "*.symbols" -exec rm {} \;
    fi
	find /tmp/kernels -name kernel.old -exec rm -rf {} \; 2>/dev/null
	echo "done."

	echo -n ">>> Installing kernels to LiveCD area..."
	(cd /tmp/kernels/uniprocessor/boot/ && tar czf $PFSENSEBASEDIR/kernels/kernel_uniprocessor.gz .) 	
	echo -n "."
	(cd /tmp/kernels/wrap/boot/ && tar czf $PFSENSEBASEDIR/kernels/kernel_wrap.gz .) 	
	echo -n "."
	(cd /tmp/kernels/developers/boot/ && tar czf $PFSENSEBASEDIR/kernels/kernel_Dev.gz .)
	echo -n "."	
	(cd /tmp/kernels/SMP/boot/ && tar czf $PFSENSEBASEDIR/kernels/kernel_SMP.gz .)
	echo -n "."
	chflags -R noschg $PFSENSEBASEDIR/boot/
	
	# Install DEV ISO kernel if we are building a dev iso
	if [ -z "${IS_DEV_ISO:-}" ]; then
		(cd $PFSENSEBASEDIR/boot/ && tar xzf $PFSENSEBASEDIR/kernels/kernel_SMP.gz -C $PFSENSEBASEDIR/boot/)
	else 
		(cd $PFSENSEBASEDIR/boot/ && tar xzf $PFSENSEBASEDIR/kernels/kernel_Dev.gz -C $PFSENSEBASEDIR/boot/)
	fi
	
	echo "done."
	
}

recompile_pfPorts() {

	if [ ! -f /tmp/pfSense_do_not_build_pfPorts ]; then 

		echo
		echo
		echo "WARNING!  We are about to run make includes."
		echo "          If you do not wish for this command press CTRL+C now!"
		echo 
		sleep 5
		# Since we are using NAT-T we need to run this prior
		# to the build.  Once NAT-T is included in FreeBSD
		# we can remove this step. 
		( cd /usr/src && make includes )
		
		pfSPORTS_COPY_BASE_DIR="/home/pfsense/tools/pfPorts"
		pfSPORTS_BASE_DIR="/usr/ports/pfPorts"

		rm -rf ${pfSPORTS_BASE_DIR}
		mkdir ${pfSPORTS_BASE_DIR}
	
		echo "===> Compiling pfPorts..."
		if [ -f /etc/make.conf ]; then
			mv /etc/make.conf /tmp/
			echo "WITHOUT_X11=yo" >> /etc/make.conf
			echo "CFLAGS=-O" >> /etc/make.conf
			MKCNF="pfPorts"
		fi
		export FORCE_PKG_REGISTER=yo

		chmod a+rx ${pfSPORTS_COPY_BASE_DIR}/Makefile.${PFSENSETAG}
		( su - root -c ${pfSPORTS_COPY_BASE_DIR}/Makefile.${PFSENSETAG} )
		
		if [ "${MKCNF}x" = "pfPortsx" ]; then
			mv /tmp/make.conf /etc/
		fi

		echo "===> End of pfPorts..."
	
	else
		echo
		echo "/tmp/pfSense_do_not_build_pfPorts is set, skipping pfPorts build..."
		echo
	fi
}

cust_overlay_host_binaries() {
    echo "===> Building syslogd..."
    (cd /usr/src/usr.sbin/syslogd && make clean && make && make install)
    echo "===> Installing syslogd to $PFSENSEBASEDIR/usr/sbin/..."
    install /usr/sbin/syslogd $PFSENSEBASEDIR/usr/sbin/
	echo "===> Building clog..."
	(cd /usr/src/usr.sbin/clog && make clean && make && make install)
    echo "===> Installing clog to $PFSENSEBASEDIR/usr/sbin/..."
    install /usr/sbin/clog $PFSENSEBASEDIR/usr/sbin/

	mkdir -p ${PFSENSEBASEDIR}/bin
	mkdir -p ${PFSENSEBASEDIR}/sbin
	mkdir -p ${PFSENSEBASEDIR}/usr/bin
	mkdir -p ${PFSENSEBASEDIR}/usr/sbin
	mkdir -p ${PFSENSEBASEDIR}/usr/lib
	mkdir -p ${PFSENSEBASEDIR}/usr/libexec
	mkdir -p ${PFSENSEBASEDIR}/usr/local/bin
	mkdir -p ${PFSENSEBASEDIR}/usr/local/sbin
	mkdir -p ${PFSENSEBASEDIR}/usr/local/lib
	mkdir -p ${PFSENSEBASEDIR}/usr/local/libexec
	
	# Temporary hack for RELENG_1_2
	mkdir -p ${PFSENSEBASEDIR}/usr/local/lib/php/extensions/no-debug-non-zts-20020429/

	# Process base system libraries
	FOUND_FILES=`cat copy.list.${PFSENSETAG}`
	NEEDEDLIBS=""
	echo ">>>> Populating newer binaries found on host jail/os (usr/local)..."
	for TEMPFILE in $FOUND_FILES; do
		echo "Looking for /${TEMPFILE} "
		if [ -f /${TEMPFILE} ]; then
			echo " Found $TEMPFILE"
			FILETYPE=`file /$TEMPFILE | grep dynamically | wc -l | awk '{ print $1 }'`
			if [ "$FILETYPE" -gt 0 ]; then
				NEEDEDLIBS="$NEEDEDLIBS `ldd /${TEMPFILE} | grep "=>" | awk '{ print $3 }'`"									
				echo "cp /${TEMPFILE} ${PFSENSEBASEDIR}/$TEMPFILE"
				cp /${TEMPFILE} ${PFSENSEBASEDIR}/$TEMPFILE
				chmod a+rx ${PFSENSEBASEDIR}/${TEMPFILE}
				if [ -d $CLONEDIR ]; then
					echo "cp /$NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}"
					cp /$NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}
				fi
			else 
				echo "Binary does not contain libraries, copying..."
				cp /${TEMPFILE} ${PFSENSEBASEDIR}/$TEMPFILE
			fi
		else
			echo "Could not find ${TEMPFILE}"
			if [ -f ${CVS_CO_DIR}/${TEMPFILE} ]; then
				FILETYPE=`file ${CVS_CO_DIR}/${TEMPFILE} | grep dynamically | wc -l | awk '{ print $1 }'`
				if [ "$FILETYPE" -gt 0 ]; then
					NEEDEDLIBS="$NEEDEDLIBS `ldd ${CVS_CO_DIR}/${TEMPFILE} | grep "=>" | awk '{ print $3 }'`"									
				fi
			fi
		fi
	done		
	echo ">>>> Installing collected library information (usr/local), please wait..."
	# Unique the libraries so we only copy them once
	NEEDEDLIBS=`for LIB in ${NEEDEDLIBS} ; do echo $LIB ; done |sort -u`
	for NEEDLIB in $NEEDEDLIBS; do
		if [ -f $NEEDLIB ]; then 
			echo "install $NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}"
			install $NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}
			if [ -d $CLONEDIR ]; then
				echo "install $NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}"
				install $NEEDLIB ${PFSENSEBASEDIR}${NEEDLIB}					
			fi
		fi
	done
	
}

report_zero_sized_files() {
objdir=${MAKEOBJDIRPREFIX:-/usr/obj}
	if [ -f $objdir/zero_sized_files.txt ]; then 
		cat $objdir/zero_sized_files.txt
		rm $objdir/zero_sized_files.txt
	fi
}

check_for_zero_size_files() {
	objdir=${MAKEOBJDIRPREFIX:-/usr/obj}
	find $PFSENSEBASEDIR -perm -+x -type f -size 0 -exec echo "WARNING: {} is 0 sized" >> $objdir/zero_sized_files.txt \;
}

# Copies all extra files to the CVS staging area and ISO staging area (as needed)
cust_populate_extra() {
    # Make devd
    ( cd ${SRCDIR}/sbin/devd; export __MAKE_CONF=${MAKE_CONF} NO_MAN=YES \
	make clean; make depend; make all; make DESTDIR=$PFSENSEBASEDIR install )

	mkdir -p ${CVS_CO_DIR}/lib

	if [ -f /usr/lib/pam_unix.so ]; then
		install -s /usr/lib/pam_unix.so ${PFSENSEBASEDIR}/usr/lib/
	fi
	
	STRUCTURE_TO_CREATE="var/run root scripts conf usr/local/share/dfuibe_installer root usr/local/bin usr/local/sbin usr/local/lib usr/local/etc usr/local/lib/php/20060613 usr/local/lib/lighttpd"
	
	for TEMPDIR in $STRUCTURE_TO_CREATE; do	
		mkdir -p ${CVS_CO_DIR}/${TEMPDIR}
		mkdir -p ${PFSENSEBASEDIR}/${TEMPDIR}
	done
	
    echo exit > $CVS_CO_DIR/root/.xcustom.sh
    touch $CVS_CO_DIR/root/.hushlogin

    # bsnmpd
    mkdir -p $CVS_CO_DIR/usr/share/snmp/defs/
    cp -R /usr/share/snmp/defs/ $CVS_CO_DIR/usr/share/snmp/defs/

    # Add lua installer items
    mkdir -p $CVS_CO_DIR/usr/local/share/dfuibe_lua/

    # This is now ready for general consumption! \o/
    mkdir -p $CVS_CO_DIR/usr/local/share/dfuibe_lua/conf/
    cp -r $BASE_DIR/tools/installer/conf $CVS_CO_DIR/usr/local/share/dfuibe_lua/

	if [ $FreeBSD_version = "7" ]; then
		echo "Using FreeBSD 7 BSDInstaller dfuibelua structure."
    	cp -r $BASE_DIR/tools/installer/installer_root_dir7 $CVS_CO_DIR/usr/local/share/dfuibe_lua/install/
	else 
		echo "Using FreeBSD 6 BSDInstaller dfuibelua structure."
		cp -r $BASE_DIR/tools/installer/installer_root_dir $CVS_CO_DIR/usr/local/share/dfuibe_lua/install/
	fi

    # Set buildtime
    date > $CVS_CO_DIR/etc/version.buildtime
    cp $BASE_DIR/tools/pfi $CVS_CO_DIR/scripts/
    cp $BASE_DIR/tools/dev_bootstrap.sh $CVS_CO_DIR/scripts/
    cp $BASE_DIR/tools/lua_installer $CVS_CO_DIR/scripts/
    cp $BASE_DIR/tools/lua_installer $CVS_CO_DIR/scripts/installer
    chmod a+rx $CVS_CO_DIR/scripts/*
    cp $BASE_DIR/tools/after_installation_routines.sh \
	$CVS_CO_DIR/usr/local/bin/after_installation_routines.sh
    chmod a+rx $CVS_CO_DIR/scripts/*

    # Suppress extra spam when logging in
    touch $CVS_CO_DIR/root/.hushlogin

    # Setup login environment
    echo > $CVS_CO_DIR/root/.shrc
    echo "/etc/rc.initial" >> $CVS_CO_DIR/root/.shrc
    echo "exit" >> $CVS_CO_DIR/root/.shrc
    echo "/etc/rc.initial" >> $CVS_CO_DIR/root/.profile
    echo "exit" >> $CVS_CO_DIR/root/.profile
	mkdir -p $PFSENSEBASEDIR/root
    echo > $PFSENSEBASEDIR/root/.shrc
    echo "/etc/rc.initial" >> $PFSENSEBASEDIR/root/.shrc
    echo "exit" >> $PFSENSEBASEDIR/root/.shrc
    echo "/etc/rc.initial" >> $PFSENSEBASEDIR/root/.profile
    echo "exit" >> $PFSENSEBASEDIR/root/.profile

	# Turn off error checking
    set +e

    # Nuke CVS dirs
    find $CVS_CO_DIR -type d -name CVS -exec rm -rf {} \; 2> /dev/null
    find $CVS_CO_DIR -type d -name "_orange-flow" -exec rm -rf {} \; 2> /dev/null

	install_custom_overlay
	
    # Enable debug if requested
    if [ ! -z "${PFSENSE_DEBUG:-}" ]; then
		touch ${CVS_CO_DIR}/debugging
    fi
}

install_custom_overlay() {
	# Extract custom overlay if it's defined.
	if [ ! -z "${custom_overlay:-}" ]; then
		echo -n "Custom overlay defined - "
	    if [ -d $custom_overlay ]; then
			echo "found directory, copying..."
			for i in $custom_overlay/*
			do
			    if [ -d $i ]; then
			        echo "copying dir: $i ..."
			        cp -R $i $CVS_CO_DIR
			    else
			        echo "copying file: $i ..."
			        cp $i $CVS_CO_DIR
			    fi
			done
		elif [ -f $custom_overlay ]; then
			echo "found file, extracting..."
			tar xzpf $custom_overlay -C $CVS_CO_DIR
		else
			echo " file not found $custom_overlay"
		fi
	fi

    # Enable debug if requested
    if [ ! -z "${PFSENSE_DEBUG:-}" ]; then
		touch ${CVS_CO_DIR}/debugging
    fi
}

install_custom_packages() {

	DEVFS_MOUNT=`mount | grep ${BASEDIR}/dev | wc -l | awk '{ print $1 }'`

	if [ "$DEVFS_MOUNT" -lt 1 ]; then
		echo "Mounting devfs ${BASEDIR}/dev ..."
		mount -t devfs devfs ${BASEDIR}/dev
	fi
		
	DESTNAME="pkginstall.sh"
	
	# Extra package list if defined.
	if [ ! -z "${custom_package_list:-}" ]; then
		# execute setup script
		./pfs_custom_pkginstall.sh
	else
		# cleanup if file does exist
		if [ -f ${FREESBIE_PATH}/extra/customscripts/${DESTNAME} ]; then
			rm ${FREESBIE_PATH}/extra/customscripts/${DESTNAME}
		fi
	fi

	# Clean up after ourselves.
	umount ${BASEDIR}/dev

}

create_pfSense_BaseSystem_Small_update_tarball() {
	VERSION=`cat $CVS_CO_DIR/etc/version`
	FILENAME=pfSense-Mini-Embedded-BaseSystem-Update-${VERSION}.tgz

	mkdir -p $UPDATESDIR

	echo ; echo Creating ${UPDATESDIR}/${FILENAME} ...

	cp ${CVS_CO_DIR}/usr/local/sbin/check_reload_status /tmp/
	cp ${CVS_CO_DIR}/usr/local/sbin/mpd /tmp/

	rm -rf ${CVS_CO_DIR}/usr/local/sbin/*
	rm -rf ${CVS_CO_DIR}/usr/local/bin/*
	install -s /tmp/check_reload_status ${CVS_CO_DIR}/usr/local/sbin/check_reload_status
	install -s /tmp/mpd ${CVS_CO_DIR}/usr/local/sbin/mpd

	du -hd0 ${CVS_CO_DIR}

	rm -f ${CVS_CO_DIR}/etc/platform
	rm -f ${CVS_CO_DIR}/etc/*passwd*
	rm -f ${CVS_CO_DIR}/etc/pw*
	rm -f ${CVS_CO_DIR}/etc/ttys

	( cd ${CVS_CO_DIR} && tar czPf ${UPDATESDIR}/${FILENAME} . )

	ls -lah ${UPDATESDIR}/${FILENAME}
	if [ -e /usr/local/sbin/gzsig ]; then 
		gzsig sign ~/.ssh/id_dsa ${UPDATESDIR}/${FILENAME}
	fi
}

fixup_updates() {

	# This step should be the last step before tarring the update, or 
	# rolling an iso.
	
	#find ${PFSENSEBASEDIR}/boot/ -type f -depth 1 -exec rm {} \;

	PREVIOUSDIR=`pwd`

	cd ${PFSENSEBASEDIR}
	rm -rf ${PFSENSEBASEDIR}/cf
	rm -rf ${PFSENSEBASEDIR}/conf
	rm -f ${PFSENSEBASEDIR}/etc/rc.conf
	rm -f ${PFSENSEBASEDIR}/etc/motd
	rm -f ${PFSENSEBASEDIR}/etc/pwd.db 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/group 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/spwd.db 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/passwd 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/master.passwd 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/fstab 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/ttys 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/etc/platform 2>/dev/null
	rm -f ${PFSENSEBASEDIR}/root/.* 2>/dev/null

	echo > ${PFSENSEBASEDIR}/root/.tcshrc
	echo "alias installer /scripts/lua_installer" > ${PFSENSEBASEDIR}/root/.tcshrc
	
	# Setup login environment
	echo > ${PFSENSEBASEDIR}/root/.shrc
	echo "/etc/rc.initial" >> ${PFSENSEBASEDIR}/root/.shrc
	echo "exit" >> ${PFSENSEBASEDIR}/root/.shrc

	mkdir -p ${PFSENSEBASEDIR}/usr/local/livefs/lib/

	echo `date` > ${PFSENSEBASEDIR}/etc/version.buildtime

	if [ -d "${PFSENSEBASEDIR}" ]; then 
		echo Removing pfSense.tgz used by installer..
		find ${PFSENSEBASEDIR} -name pfSense.tgz -exec rm {} \;
	fi 
	
	cd $PREVIOUSDIR

}

cust_fixup_wrap() {

	echo "Fixing up WRAP Specific items..."
    cp $CVS_CO_DIR/boot/device.hints_wrap \
            $PFSENSEBASEDIR/boot/device.hints
    cp $CVS_CO_DIR/boot/loader.conf_wrap \
            $PFSENSEBASEDIR/boot/loader.conf
    cp $CVS_CO_DIR/etc/ttys_wrap \
            $PFSENSEBASEDIR/etc/ttys

    echo `date` > $PFSENSEBASEDIR/etc/version.buildtime
    echo "" > $PFSENSEBASEDIR/etc/motd

    mkdir -p $PFSENSEBASEDIR/cf/conf/backup

    echo /etc/rc.initial > $PFSENSEBASEDIR/root/.shrc
    echo exit >> $PFSENSEBASEDIR/root/.shrc
    rm -f $PFSENSEBASEDIR/usr/local/bin/after_installation_routines.sh 2>/dev/null

    echo "embedded" > $PFSENSEBASEDIR/etc/platform
    echo "wrap" > $PFSENSEBASEDIR/boot/kernel/pfsense_kernel.txt

	echo "-D" >> $PFSENSEBASEDIR/boot.config

}

create_FreeBSD_system_update() {
	VERSION="FreeBSD"
	FILENAME=pfSense-Embedded-Update-${VERSION}.tgz
	mkdir -p $UPDATESDIR

	PREVIOUSDIR=`pwd`

	cd ${CLONEDIR}
	# Remove some fat and or conflicting
	# freebsd files
	rm -rf etc/
	rm -rf var/
	rm -rf usr/share/
	echo "Creating ${UPDATESDIR}/${FILENAME} update file..."
	tar czPf ${UPDATESDIR}/${FILENAME} .

	echo "Signing ${UPDATESDIR}/${FILENAME} update file..."
	if [ -e /usr/local/sbin/gzsig ]; then 	
		gzsig sign ~/.ssh/id_dsa ${UPDATESDIR}/${FILENAME}
	fi
	
	cd $PREVIOUSDIR
	
}

create_pfSense_Full_update_tarball() {
	VERSION=`cat ${PFSENSEBASEDIR}/etc/version`
	FILENAME=pfSense-Full-Update-${VERSION}-`date "+%Y%m%d-%H%M"`.tgz
	mkdir -p $UPDATESDIR

	PREVIOUSDIR=`pwd`

	echo ; echo "Deleting files listed in ${PRUNE_LIST}"
	set +e
	
	# Ensure that we do not step on /root/ scripts that
	# control auto login, console menu, etc.
	rm -f ${PFSENSEBASEDIR}/root/.* 2>/dev/null
		
	(cd ${PFSENSEBASEDIR} && sed 's/^#.*//g' ${PRUNE_LIST} | xargs rm -rvf > /dev/null 2>&1)

	echo ; echo Creating ${UPDATESDIR}/${FILENAME} ...
	cd ${PFSENSEBASEDIR} && tar czPf ${UPDATESDIR}/${FILENAME} .

	echo "Signing ${UPDATESDIR}/${FILENAME} update file..."
	if [ -e /usr/local/sbin/gzsig ]; then 
		gzsig sign ~/.ssh/id_dsa ${UPDATESDIR}/${FILENAME}
	fi

	cd $PREVIOUSDIR
}

create_pfSense_Embedded_update_tarball() {
	VERSION=`cat ${PFSENSEBASEDIR}/etc/version`
	FILENAME=pfSense-Embedded-Update-${VERSION}-`date "+%Y%m%d-%H%M"`.tgz
	mkdir -p $UPDATESDIR

	PREVIOUSDIR=`pwd`

	echo ; echo "Deleting files listed in ${PRUNE_LIST}"
	set +e
	(cd ${PFSENSEBASEDIR} && sed 's/^#.*//g' ${PRUNE_LIST} | xargs rm -rvf > /dev/null 2>&1)

	# Remove all other kernels and replace full kernel with the embedded
	# kernel that was built during the builder process
	mv ${PFSENSEBASEDIR}/kernels/kernel_wrap.gz ${PFSENSEBASEDIR}/boot/kernel/kernel.gz
	rm -rf ${PFSENSEBASEDIR}/kernels/*

	echo ; echo Creating ${UPDATESDIR}/${FILENAME} ...
	cd ${PFSENSEBASEDIR} && tar czPf ${UPDATESDIR}/${FILENAME} .

	echo "Signing ${UPDATESDIR}/${FILENAME} update file..."
	if [ -e /usr/local/sbin/gzsig ]; then 
		gzsig sign ~/.ssh/id_dsa ${UPDATESDIR}/${FILENAME}
	fi
	
	cd $PREVIOUSDIR
	
}

create_pfSense_Small_update_tarball() {
	VERSION=`cat $CVS_CO_DIR/etc/version`
	FILENAME=pfSense-Mini-Embedded-Update-${VERSION}-`date "+%Y%m%d-%H%M"`.tgz

	PREVIOUSDIR=`pwd`

	mkdir -p $UPDATESDIR

	echo ; echo Creating ${UPDATESDIR}/${FILENAME} ...

	cp ${CVS_CO_DIR}/usr/local/sbin/check_reload_status /tmp/
	cp ${CVS_CO_DIR}/usr/local/sbin/mpd /tmp/

	rm -rf ${CVS_CO_DIR}/usr/local/sbin/*
	rm -rf ${CVS_CO_DIR}/usr/local/bin/*
	install -s /tmp/check_reload_status ${CVS_CO_DIR}/usr/local/sbin/check_reload_status
	install -s /tmp/mpd ${CVS_CO_DIR}/usr/local/sbin/mpd

	du -hd0 ${CVS_CO_DIR}

	rm -f ${CVS_CO_DIR}/etc/platform
	rm -f ${CVS_CO_DIR}/etc/*passwd*
	rm -f ${CVS_CO_DIR}/etc/pw*
	rm -f ${CVS_CO_DIR}/etc/ttys*
	
	cd ${CVS_CO_DIR} && tar czPf ${UPDATESDIR}/${FILENAME} .

	ls -lah ${UPDATESDIR}/${FILENAME}

	if [ -e /usr/local/sbin/gzsig ]; then 
		gzsig sign ~/.ssh/id_dsa ${UPDATESDIR}/${FILENAME}
	fi

	cd $PREVIOUSDIR

}

# Create tarball of pfSense cvs directory
create_pfSense_tarball() {
	rm -f $CVS_CO_DIR/boot/*

	PREVIOUSDIR=`pwd`

	find $CVS_CO_DIR -name CVS -exec rm -rf {} \; 2>/dev/null
	find $CVS_CO_DIR -name "_orange-flow" -exec rm -rf {} \; 2>/dev/null

	cd $CVS_CO_DIR && tar czPf /tmp/pfSense.tgz .

	cd $PREVIOUSDIR
}

# Copy tarball of pfSense cvs directory to FreeSBIE custom directory
copy_pfSense_tarball_to_custom_directory() {
	rm -rf $LOCALDIR/customroot/*

	tar  xzPf /tmp/pfSense.tgz -C $LOCALDIR/customroot/

	rm -f $LOCALDIR/customroot/boot/*
	rm -rf $LOCALDIR/customroot/cf/conf/config.xml
	rm -rf $LOCALDIR/customroot/conf/config.xml
	rm -rf $LOCALDIR/customroot/conf
	mkdir -p $LOCALDIR/customroot/conf

	mkdir -p $LOCALDIR/var/db/
	chroot $LOCALDIR /bin/ln -s /var/db/rrd /usr/local/www/rrd

	chroot $LOCALDIR/ cap_mkdb /etc/master.passwd

}

copy_pfSense_tarball_to_freesbiebasedir() {
	PREVIOUSDIR=`pwd`
	cd $LOCALDIR
	tar  xzPf /tmp/pfSense.tgz -C $FREESBIEBASEDIR
	cd $PREVIOUSDIR
}

# Set image as a CDROM type image
set_image_as_cdrom() {
	echo cdrom > $CVS_CO_DIR/etc/platform
}

#Create a copy of FREESBIEBASEDIR. This is useful to modify the live filesystem
clone_system_only()
{

	PREVIOUSDIR=`pwd`

	echo -n "Cloning $FREESBIEBASEDIR to $FREESBIEISODIR..."

	mkdir -p $FREESBIEISODIR || print_error_pfS
	if [ -r $FREESBIEISODIR ]; then
	      chflags -R noschg $FREESBIEISODIR || print_error_pfS
	      rm -rf $FREESBIEISODIR/* || print_error_pfS
	fi

	#We are making files containing /usr and /var partition

	#Before uzip'ing filesystems, we have to save the directories tree
	mkdir -p $FREESBIEISODIR/dist
	mtree -Pcdp $FREESBIEBASEDIR/usr > $FREESBIEISODIR/dist/FreeSBIE.usr.dirs
	mtree -Pcdp $FREESBIEBASEDIR/var > $FREESBIEISODIR/dist/FreeSBIE.var.dirs

	#Define a function to create the vnode $1 of the size expected for
	#$FREESBIEBASEDIR/$2 directory, mount it under $FREESBIEISODIR/$2
	#and print the md device
	create_vnode() {
	    UFSFILE=$1
	    CLONEDIR=$FREESBIEBASEDIR/$2
	    MOUNTPOINT=$FREESBIEISODIR/$2
	    cd $CLONEDIR
	    FSSIZE=$((`du -kd 0 | cut -f 1` + 94000))
	    dd if=/dev/zero of=$UFSFILE bs=1k count=$FSSIZE > /dev/null 2>&1

	    DEVICE=/dev/`mdconfig -a -t vnode -f $UFSFILE`
	    newfs $DEVICE > /dev/null 2>&1
	    mkdir -p $MOUNTPOINT
	    mount -o noatime ${DEVICE} $MOUNTPOINT
	    echo ${DEVICE}
	}

	#Umount and detach md devices passed as parameters
	umount_devices() {
	    for i in $@; do
	        umount ${i}
	        mdconfig -d -u ${i}
	    done
	}

	mkdir -p $FREESBIEISODIR/uzip
	MDDEVICES=`create_vnode $FREESBIEISODIR/uzip/usr.ufs usr`
	MDDEVICES="$MDDEVICES `create_vnode $FREESBIEISODIR/uzip/var.ufs var`"

	trap "umount_devices $MDDEVICES; exit 1" INT

	cd $FREESBIEBASEDIR

	find . -print -depth | cpio --quiet -pudm $FREESBIEISODIR

	umount_devices $MDDEVICES

	trap "" INT

	echo " [DONE]"
	
	cd $PREVIOUSDIR
}

checkout_pfSense() {
	PREVIOUSDIR=`pwd`
	echo ">>> Checking out pfSense version ${PFSENSETAG}..."
	rm -rf $CVS_CO_DIR
	if [ -z "${USE_GIT:-}" ]; then
		(cd $BASE_DIR && cvs -d ${BASE_DIR}/cvsroot co pfSense -r ${PFSENSETAG})
	else
		echo "Using GIT to checkout ${PFSENSETAG}"
		# XXX: do we need to revert the co to HEAD if it has been 
		#      checked out on another branch?
		if [ "${PFSENSETAG}" != "HEAD" ]; then
			(cd $BASE_DIR && git checkout ${PFSENSETAG})
		fi
		fixup_libmap
	fi
	cd $PREVIOUSDIR
}

checkout_freesbie() {
	echo ">>> Getting FreeSBIE"
	rm -rf $LOCALDIR
}

print_flags() {

	printf "         CVS User: %s\n" $CVS_USER
	printf "        Verbosity: %s\n" $BE_VERBOSE
	printf "         Base dir: %s\n" $BASE_DIR
	printf "     Checkout dir: %s\n" $CVS_CO_DIR
	printf "      Custom root: %s\n" $CUSTOMROOT
	printf "   CVS IP address: %s\n" $CVS_IP
	printf "      Updates dir: %s\n" $UPDATESDIR
	printf "     pfS Base dir: %s\n" $PFSENSEBASEDIR
	printf "    FreeSBIE path: %s\n" $FREESBIE_PATH
	printf "    FreeSBIE conf: %s\n" $FREESBIE_CONF
	printf "       Source DIR: %s\n" $SRCDIR
	printf "        Clone DIR: %s\n" $CLONEDIR
	printf "   Custom overlay: %s\n" $custom_overlay
	printf "  pfSense version: %s\n" $FreeBSD_version
	printf "   FreeBSD branch: %s\n" $freebsd_branch
	printf "      pfSense Tag: %s\n" $PFSENSETAG
	printf " MAKEOBJDIRPREFIX: %s\n" $MAKEOBJDIRPREFIX
	printf "            EXTRA: %s\n" $EXTRA
	printf "     BUILDMODULES: %s\n" $BUILDMODULES
	printf "          ISOPATH: %s\n" $ISOPATH
	printf "          IMGPATH: %s\n" $IMGPATH

	echo "Sleeping for 5 seconds..."

	sleep 5

}

clear_custom() {
	echo ">> Clearing custom/*"
	rm -rf $LOCALDIR/customroot/*
}

backup_pfSense() {
	echo ">>> Backing up pfSense repo"
	cp -R $CVS_CO_DIR $BASE_DIR/pfSense_bak
}

restore_pfSense() {
	echo ">>> Restoring pfSense repo"
	cp -R $BASE_DIR/pfSense_bak $CVS_CO_DIR
}

freesbie_make() {
	(cd ${FREESBIE_PATH} && make $*)
}

update_cvs_depot() {
	if [ -z "${USE_GIT:-}" ]; then
		echo "Launching cvsup pfSense-supfile..."
		cvsup pfSense-supfile
		rm -rf pfSense
		echo "Updating ${BASE_DIR}/pfSense..."
		rm -rf $BASE_DIR/pfSense
		(cd ${BASE_DIR} && cvs -d /home/pfsense/cvsroot co -r ${PFSENSETAG} pfSense)
		(cd ${BASE_DIR}/tools/ && cvs update -d)
	else
		if [ -e "${BASE_DIR}/mainline" ]; then
			echo "Updating cloned GIT repo directory..."
			(cd ${BASE_DIR} && git pull)
		else 
			echo "Cloning REPO using GIT..."
			(cd ${BASE_DIR} && git clone ${GIT_REPO} pfSense)		
		fi
	fi
}

make_world() {
    # Check if the world and kernel are already built and set
    # the NO variables accordingly
    objdir=${MAKEOBJDIRPREFIX:-/usr/obj}

    if [ -f "${objdir}/.world.done" ]; then
		export NO_BUILDWORLD=yo
    fi

    # Make world
    freesbie_make buildworld
    touch ${objdir}/.world.done

	freesbie_make installworld

}

setup_nanobsd_etc ( ) {
	echo "## configure nanobsd /etc"

	cd ${CLONEDIR}

	# create diskless marker file
	touch etc/diskless
	touch nanobuild

	# Make root filesystem R/O by default
	echo "root_rw_mount=NO" >> etc/defaults/rc.conf

	# save config file for scripts
	# echo "NANO_DRIVE=${NANO_DRIVE}" > etc/nanobsd.conf

	echo "/dev/ufs/root0 / ufs ro 1 1" > etc/fstab
	echo "/dev/ufs/cfg /cfg ufs rw,noauto 2 2" >> etc/fstab
	echo "/dev/ufs/cf /cf ufs ro 1 1" >> etc/fstab
	mkdir -p cfg
}

setup_nanobsd ( ) {
	echo "## configure nanobsd setup"
	echo "### log: ${MAKEOBJDIRPREFIX}/_.dl"

	cd ${CLONEDIR}

	# Move /usr/local/etc to /etc/local so that the /cfg stuff
	# can stomp on it.  Otherwise packages like ipsec-tools which
	# have hardcoded paths under ${prefix}/etc are not tweakable.
	if [ -d usr/local/etc ] ; then
		(
		mkdir etc/local
		cd usr/local/etc
		find . -print | cpio -dumpl ../../../etc/local
		cd ..
		rm -rf etc
		ln -s ../../etc/local etc
		)
	fi
	# Create /conf directory hier
	for d in etc
	do
		# link /$d under /${CONFIG_DIR}
		# we use hard links so we have them both places.
		# the files in /$d will be hidden by the mount.
		# XXX: configure /$d ramdisk size
		mkdir -p ${CONFIG_DIR}/base/$d ${CONFIG_DIR}/default/$d
		find $d -print | cpio -dumpl ${CONFIG_DIR}/base/
	done

	echo "$NANO_RAM_ETCSIZE" > ${CONFIG_DIR}/base/etc/md_size
	# add /nano/base/var manually for md_size 
	mkdir -p ${CONFIG_DIR}/base/var
	echo "$NANO_RAM_TMPVARSIZE" > ${CONFIG_DIR}/base/var/md_size 

	# pick up config files from the special partition
	echo "mount -o ro /dev/ufs/cfg" > ${CONFIG_DIR}/default/etc/remount

	# Put /tmp on the /var ramdisk (could be symlink already)
	rmdir tmp || true
	rm -rf tmp || true
	ln -s var/tmp tmp

}

prune_usr() {

	# Remove all empty directories in /usr 
	find ${NANO_WORLDDIR}/usr -type d -depth -print |
		while read d
		do
			rmdir $d > /dev/null 2>&1 || true 
		done
}

FlashDevice () {
    . FlashDevice.sub
    sub_FlashDevice $1 $2
}

create_i386_diskimage ( ) {
	echo "## build diskimage"
	echo "### log: ${MAKEOBJDIRPREFIX}/_.di"
	TIMESTAMP=`date "+%Y%m%d.%H%M"`
	echo $NANO_MEDIASIZE $NANO_IMAGES \
		$NANO_SECTS $NANO_HEADS \
		$NANO_CODESIZE $NANO_CONFSIZE $NANO_DATASIZE |
	awk '
	{
		printf "# %s\n", $0

		# size of cylinder in sectors
		cs = $3 * $4

		# number of full cylinders on media
		cyl = int ($1 / cs)

		# output fdisk geometry spec, truncate cyls to 1023
		if (cyl <= 1023)
			print "g c" cyl " h" $4 " s" $3
		else
			print "g c" 1023 " h" $4 " s" $3

		if ($7 > 0) { 
			# size of data partition in full cylinders
			dsl = int (($7 + cs - 1) / cs)
		} else {
			dsl = 0;
		}

		# size of config partition in full cylinders
		csl = int (($6 + cs - 1) / cs)

		if ($5 == 0) {
			# size of image partition(s) in full cylinders
			isl = int ((cyl - dsl - csl) / $2)
		} else {
			isl = int (($5 + cs - 1) / cs)
		}

		# First image partition start at second track
		print "p 1 165 " $3, isl * cs - $3
		c = isl * cs;

		# Second image partition (if any) also starts offset one 
		# track to keep them identical.
		if ($2 > 1) {
			print "p 2 165 " $3 + c, isl * cs - $3
			c += isl * cs;
		}

		# Config partition starts at cylinder boundary.
		print "p 3 165 " c, csl * cs
		c += csl * cs

		# Data partition (if any) starts at cylinder boundary.
		if ($7 > 0) {
			print "p 4 165 " c, dsl * cs
		} else if ($7 < 0 && $1 > $c) {
			print "p 4 165 " c, $1 - $c
		} else if ($1 < c) {
			print "Disk space overcommitted by", \
			    c - $1, "sectors" > "/dev/stderr"
			exit 2
		}
	}
	' > ${MAKEOBJDIRPREFIX}/_.fdisk

	IMG=${MAKEOBJDIRPREFIX}/nanobsd.full.$NANO_NAME.$PFSENSETAG.$TIMESTAMP.img
	MNT=${MAKEOBJDIRPREFIX}/_.mnt
	mkdir -p ${MNT}

	dd if=/dev/zero of=${IMG} bs=${NANO_SECTS}b \
	    count=`expr ${NANO_MEDIASIZE} / ${NANO_SECTS}`

	MD=`mdconfig -a -t vnode -f ${IMG} -x ${NANO_SECTS} -y ${NANO_HEADS}`

	fdisk -i -f ${MAKEOBJDIRPREFIX}/_.fdisk ${MD}
	fdisk ${MD}
	# XXX: params
	# XXX: pick up cached boot* files, they may not be in image anymore.
	boot0cfg -B -b ${CLONEDIR}/${NANO_BOOTLOADER} ${NANO_BOOT0CFG} ${MD}
	bsdlabel -w -B -b ${CLONEDIR}/boot/boot ${MD}s1
	bsdlabel ${MD}s1

	# Create first image
	newfs ${NANO_NEWFS} /dev/${MD}s1a
	tunefs -L root0 /dev/${MD}s1a
	mount /dev/${MD}s1a ${MNT}
	df -i ${MNT}
	( cd ${CLONEDIR} && find . -print | cpio -dump ${MNT} )
	df -i ${MNT}
	( cd ${MNT} && mtree -c ) > ${MAKEOBJDIRPREFIX}/_.mtree
	( cd ${MNT} && du -k ) > ${MAKEOBJDIRPREFIX}/_.du
	umount ${MNT}

	if [ $NANO_IMAGES -gt 1 -a $NANO_INIT_IMG2 -gt 0 ] ; then
		# Duplicate to second image (if present)
		dd if=/dev/${MD}s1 of=/dev/${MD}s2 bs=64k
		tunefs -L root1 /dev/${MD}s2a
		mount /dev/${MD}s2a ${MNT}
		for f in ${MNT}/etc/fstab ${MNT}/conf/base/etc/fstab
		do
			sed -i "" "s/root0/root1/g" $f
		done
		umount ${MNT}

	fi
	
	# Create Config slice
	newfs ${NANO_NEWFS} /dev/${MD}s3
	tunefs -L cfg /dev/${MD}s3
	# XXX: fill from where ?

	# Create Data slice, if any.
	if [ $NANO_DATASIZE -gt 0 ] ; then
		newfs ${NANO_NEWFS} /dev/${MD}s4
		tunefs -L cf /dev/${MD}s4
                # Mount data partition and copy contents of /cf
                # Can be used later to create custom default config.xml while building
                mount /dev/${MD}s4 ${MNT}
                ( cd ${CLONEDIR}/cf && find . -print | cpio -dump ${MNT} )
                umount ${MNT}
	fi

	dd if=/dev/${MD}s1 of=${MAKEOBJDIRPREFIX}/nanobsd.slice.$NANO_NAME.$PFSENSETAG.$TIMESTAMP.img bs=64k
	mdconfig -d -u $MD
	gzip -9 ${MAKEOBJDIRPREFIX}/nanobsd.slice.$NANO_NAME.$PFSENSETAG.$TIMESTAMP.img
	gzip -9 ${MAKEOBJDIRPREFIX}/nanobsd.full.$NANO_NAME.$PFSENSETAG.$TIMESTAMP.img
}
