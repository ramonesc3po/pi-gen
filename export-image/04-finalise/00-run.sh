#!/bin/bash -e

USER=${FIRST_USER_NAME}

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
ExecStart=-/sbin/agetty --autologin ${USER} --noclear %I \$TERM
EOF
        sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=${USER}/"
        disable_raspi_config_at_boot
    fi
}

do_config_xsession() {
    cat > /home/${USER}/.Xsession << EOF
xset s off
xset -dpms
xset s noblank
sed -i 's/"exited_cleanly": false/"exited_cleanly": true/' ~/.config/chromium-browser Default/Preferences
chromium-browser --noerrdialogs --kiosk https://google.com --incognito --disable-translate --window-size=1920,1080 --window-position=0,0
EOF
}

do_req_config() {
    do_enable_autologin \
    && do_config_xsession
}

run() {
    do_req_config
}

run