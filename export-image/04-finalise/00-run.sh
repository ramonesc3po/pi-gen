#!/bin/bash -e

ln -nsf /var/run/dbus/system_bus_socket "${ROOTFS_DIR}/var/run/dbus/system_bus_socket"

on_chroot <<SELLEOF
BOOT_MODE=$1
PACKAGES_DEP=( chromium-browser unclutter lightdm )

do_make_image(){
    sudo apt-get update \
    && sudo apt-get upgrade -y \
    && sudo apt-get dist-upgrade -y \
    && sudo apt-get install ${PACKAGES_DEP} -y \
    && sudo apt-get clean
}

disable_raspi_config_at_boot() {
  if [ -e /etc/profile.d/raspi-config.sh ]; then
    rm -f /etc/profile.d/raspi-config.sh
    if [ -e /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf ]; then
      rm /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf
    fi
    telinit q
  fi
}

do_enable_autologin() {
    if [ -e /etc/init.d/lightdm ]; then
        systemctl set-default graphical.target
        ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
        cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${FIRST_USER_NAME} --noclear %I \$TERM
EOF
        sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=${FIRST_USER_NAME}/"
        disable_raspi_config_at_boot
    else
        echo -e "Try install lightdm"
        sudo apt-get install lightdm -y && do_enable_autologin
    fi
}

do_config_xsession() {
    cat > /home/pi/.Xsession << EOF
xset s off
xset -dpms
xset s noblank
sed -i 's/"exited_cleanly": false/"exited_cleanly": true/' ~/.config/chromium-browser Default/Preferences
chromium-browser --noerrdialogs --kiosk https://google.com --incognito --disable-translate --window-size=1920,1080 --window-position=0,0
EOF
}

do_raspi_config_screen() {
    sed /boot/config.txt -i -e "s/^\(#\|\)disable_overscan=.*/disable_overscan=1/" \
    ; echo "disable_splash=1" >> /boot/config.txt \
    ; sed /boot/cmdline.txt -i -e "s/$/ splash quiet plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0/" \
    ; sed /boot/cmdline.txt -i -e "s/console=tty1/console=tty3/"
}

do_req_config() {
    do_enable_autologin \
    && do_config_xsession \
    && do_raspi_config_screen
}

run() {
    if [ "${BOOT_MODE:-none}" = "first-setup" ]; then
        do_make_image && do_req_config
    else
        do_req_config
    fi
}

run
SELLEOF