SHELL=/bin/bash
TARGET_IMG=usbarmory-debian-stretch.raw

debian:
	truncate -s 3500MiB ${TARGET_IMG}
	/sbin/parted ${TARGET_IMG} --script mklabel msdos
	/sbin/parted ${TARGET_IMG} --script mkpart primary ext4 5M 100%
	sudo umount rootfs/ || true
	sudo /sbin/losetup -d /dev/loop0 || true
	sudo /sbin/losetup /dev/loop0 ${TARGET_IMG} -o 5242880 --sizelimit 3500MiB
	sudo /sbin/mkfs.ext4 -F /dev/loop0
	sudo /sbin/losetup -d /dev/loop0
	mkdir -p rootfs
	sudo mount -o loop,offset=5242880 -t ext4 ${TARGET_IMG} rootfs/
	sudo mkdir -p rootfs/etc/flash-kernel rootfs/etc/default
	echo 'Inverse Path USB armory' | sudo tee rootfs/etc/flash-kernel/machine
	echo 'LINUX_KERNEL_CMDLINE_DEFAULTS="root=/dev/mmcblk0p1 rootwait rw"' | sudo tee rootfs/etc/default/flash-kernel
	sudo qemu-debootstrap --keep-debootstrap-dir --arch=armhf --include=ssh,sudo,ntpdate,fake-hwclock,openssl,vim,nano,cryptsetup,lvm2,locales,less,cpufrequtils,isc-dhcp-server,haveged,whois,iw,wpasupplicant,dbus,busybox,linux-image-armmp,u-boot-imx,u-boot-tools,flash-kernel stretch rootfs http://ftp.debian.org/debian/
	sudo cp conf/rc.local rootfs/etc/rc.local
	sudo chmod u+x rootfs/etc/rc.local
	sudo cp conf/sources.list rootfs/etc/apt/sources.list
	sudo cp conf/dhcpd.conf rootfs/etc/dhcp/dhcpd.conf
	echo '/dev/mmcblk0 0x60000 0x2000' | sudo tee rootfs/etc/fw_env.config
	sudo sed -i -e 's/INTERFACESv4=""/INTERFACESv4="usb0"/' rootfs/etc/default/isc-dhcp-server
	echo "tmpfs /tmp tmpfs defaults 0 0" | sudo tee rootfs/etc/fstab
	echo -e "\nUseDNS no" | sudo tee -a rootfs/etc/ssh/sshd_config
	echo "nameserver 8.8.8.8" | sudo tee rootfs/etc/resolv.conf
	sudo chroot rootfs systemctl mask getty-static.service
	sudo chroot rootfs systemctl mask display-manager.service
	sudo chroot rootfs systemctl mask hwclock-save.service
	echo "ledtrig_heartbeat" | sudo tee -a rootfs/etc/modules
	echo "ci_hdrc_imx" | sudo tee -a rootfs/etc/modules
	echo "g_ether" | sudo tee -a rootfs/etc/modules
	echo "options g_ether use_eem=0 dev_addr=1a:55:89:a2:69:41 host_addr=1a:55:89:a2:69:42" | sudo tee -a rootfs/etc/modprobe.d/usbarmory.conf
	echo -e 'auto usb0\nallow-hotplug usb0\niface usb0 inet static\n  address 10.0.0.1\n  netmask 255.255.255.0\n  gateway 10.0.0.2'| sudo tee -a rootfs/etc/network/interfaces
	echo "usbarmory" | sudo tee rootfs/etc/hostname
	echo "usbarmory  ALL=(ALL) NOPASSWD: ALL" | sudo tee -a rootfs/etc/sudoers
	echo -e "127.0.1.1\tusbarmory" | sudo tee -a rootfs/etc/hosts
	sudo chroot rootfs /usr/sbin/useradd -s /bin/bash -p `sudo chroot rootfs mkpasswd -m sha-512 usbarmory` -m usbarmory
	sudo rm rootfs/etc/ssh/ssh_host_*
	sudo chroot rootfs apt-get clean
	sudo chroot rootfs fake-hwclock
	sudo rm -f rootfs/usr/bin/qemu-arm-static
	sudo dd if=rootfs/usr/lib/u-boot/usbarmory/u-boot.imx of=${TARGET_IMG} bs=512 seek=2 conv=fsync conv=notrunc
	sudo umount rootfs
	zip -j ${TARGET_IMG}.zip ${TARGET_IMG}

.DEFAULT_GOAL := debian
all: debian
clean:
	sudo losetup -d /dev/loop0 || true
	sudo umount rootfs || true
	rm -f *.raw *.zip
	rmdir rootfs || true
