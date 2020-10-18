#!/bin/bash

NAME="ArchLinuxARM-odroid-n2-latest"
IMAGE="ArchLinuxARM-odroid-c4"

platform_variables() {
    echo "WAYLAND: set to 1 to install wayland GL libraries instead of fbdev."
    echo "DISABLE_MALIGL: set to 1 to disable installation of mali libraries."
    echo "MAINLINE_KERNEL: set to 1 to use mainline kernel."
    echo "PANFROST_KERNEL: set to 1 to use panfrost enabled kernel."
}

platform_pre_chroot() {
    echo "Platform pre-chroot..."

    if [ "${MAINLINE_KERNEL}" = "1" ]; then
        alarm_build_package linux-odroid-n2-57
        alarm_build_package dkms-mali-bifrost-next
        alarm_build_package rtl88xxau-aircrack-dkms-git
    elif [ "${PANFROST_KERNEL}" = "1" ]; then
        alarm_build_package linux-odroid-n2-panfrost-59
        alarm_build_package rtl88xxau-aircrack-dkms-git
        alarm_build_package mesa-arm-git
    else
        alarm_build_package linux-odroid-c4
    fi

    if [ "${DISABLE_MALIGL}" != "1" ]; then
        if [ "${WAYLAND}" != "1" ]; then
            alarm_build_package odroid-c4-libgl
            alarm_build_package odroid-gl4es
        else
            alarm_build_package odroid-c4-libgl
        fi
    fi

    alarm_build_package uboot-odroid-c4
    alarm_build_package odroid-alsa
}

platform_chroot_setup() {
    echo "Platform chroot-setup..."

    # Kernel
    yes | pacman -Rcs linux-odroid-n2
    yes | pacman -Rcs uboot-odroid-n2

    if [ "${MAINLINE_KERNEL}" = "1" ]; then
        alarm_install_package linux-odroid-n2-57-5
        alarm_install_package linux-odroid-n2-57-headers

        yes | pacman -S --noconfirm dkms

        # Wireless
        alarm_install_package rtl88xxau-aircrack-dkms-git

        # GPU kernel driver
        alarm_install_package dkms-mali-bifrost
    elif [ "${PANFROST_KERNEL}" = "1" ]; then
        alarm_install_package linux-odroid-n2-panfrost-59-5
        alarm_install_package linux-odroid-n2-panfrost-59-headers

        yes | pacman -S --noconfirm dkms

        # Wireless
        alarm_install_package rtl88xxau-aircrack-dkms-git

        # mesa git for panfrost
        alarm_install_package mesa-arm-git

        # Enable mesa bifrost support (still under development)
        echo "PAN_MESA_DEBUG=bifrost" >> /etc/environment
    else
        alarm_install_package linux-odroid-c4-4.9
        alarm_install_package linux-odroid-c4-headers
    fi

    # U-Boot
    alarm_install_package uboot-odroid-c4

    # Audio support
    alarm_install_package odroid-alsa

    if [ "${DISABLE_MALIGL}" != "1" ]; then
        if [ "${WAYLAND}" != "1" ]; then
            alarm_install_package odroid-c4-libgl-fb
            alarm_install_package odroid-gl4es
        fi
    fi

    # Customizations
    cp /mods/boot/boot-logo.alarm.bmp.gz /boot/boot-logo.bmp.gz

    if [ "${MAINLINE_KERNEL}" = "1" ]; then
        echo "Copy boot.ini adapted for mainline kernel..."
        cp /mods/boot/boot.c4.mainline.ini /boot/boot.ini
    elif [ "${PANFROST_KERNEL}" = "1" ]; then
        echo "Copy boot.ini adapted for mainline kernel..."
        cp /mods/boot/boot.c4.mainline.ini /boot/boot.ini
    else
        echo "Copy boot.ini adapted for c4..."
        cp /mods/boot/boot.c4.hardkernel.ini /boot/boot.ini
    fi
}

platform_chroot_setup_exit() {
    echo "Platform chroot-setup-exit..."
    # Install at last since this causes issues
    if [ "${DISABLE_MALIGL}" != "1" ]; then
        if [ "${WAYLAND}" = "1" ]; then
            alarm_install_package odroid-c4-libgl-wl
        fi
    fi

    cp /mods/etc/default/cpupower.c4 /etc/default/cpupower
}

platform_post_chroot() {
    echo "Platform post-chroot..."

    echo "Flashing U-Boot..."
    sudo dd if=root/boot/u-boot.bin of=${LOOP} conv=fsync,notrunc bs=512 seek=1
    sync
}
