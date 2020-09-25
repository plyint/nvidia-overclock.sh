#!/bin/sh
################################################################################
# Copyright (c) 2020 Plyint, LLC <contact@plyint.com>. All Rights Reserved.
# This file is licensed under the MIT License (MIT). 
# Please see LICENSE.txt for more information.
#
# DESCRIPTION:
# A simple script to manage overclocking of NVIDIA Graphics cards on Linux.
#
# To use it, please perform the following steps:
# (1) Update the values in the overclock() function with values for your GPUs.
# (2) Install the script by changing to its directory and running:
#
#     ./nvidia-overclock.sh install-svc -x
#
#     This will install the service and use "startx" to automatically start
#     XWindows.  If you already have XWindows installed and configured to run
#			automatically on boot, then omit the -x option:
# 
#      ./nvidia-overclock.sh install-svc
#
# (3) Reboot the system and XWindows should start automatically with your GPUs
#     set to the specified overclocked values.
#
# For the full documentation and detailed requirements, please read the 
# accompanying README.md file.
################################################################################

LOG_FILE="/var/log/nvidia-overclock.log"
LOG=0

overclock () {
  # The following default overclock values for the NVIDIA GTX 1070 
  # were found on average to be stable:
  # - Graphics Clock       = 100
  # - Memory Transfer Rate = 1300
  #
  # Adjust these values for each card as needed.  Some cards are more 
  # unstable than others and will only tolerate less overclocking.  Other
  # cards might tolerate above normal overclocking. If you are unsure of the 
  # starting values to use for your graphics cards, try searching online
  # for what other people with your same graphics cards have found to be stable.
  #
  # Note: The lines below were used to configure a system with 6 graphics cards.
  # You will neeed to add/remove lines based on the number of graphics cards in 
  # your particular system.
  log "Calling nvidia-settings to overclock GPU(s).."
  log "$(nvidia-settings -c :0 -a '[gpu:0]/GPUGraphicsClockOffset[3]=100' -a '[gpu:0]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:1]/GPUGraphicsClockOffset[3]=100' -a '[gpu:1]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:2]/GPUGraphicsClockOffset[3]=100' -a '[gpu:2]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:3]/GPUGraphicsClockOffset[3]=100' -a '[gpu:3]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:4]/GPUGraphicsClockOffset[3]=100' -a '[gpu:4]/GPUMemoryTransferRateOffset[3]=1300')"
  log "$(nvidia-settings -c :0 -a '[gpu:5]/GPUGraphicsClockOffset[3]=100' -a '[gpu:5]/GPUMemoryTransferRateOffset[3]=1300')"
}

abs_filename() {
  # $1 : relative filename
  filename="$1"
  parentdir="$(dirname "${filename}")"

  if [ -d "${filename}" ]; then
    cd "${filename}" && pwd
  elif [ -d "${parentdir}" ]; then
    echo "$(cd "${parentdir}" && pwd)/$(basename "${filename}")"
  fi
}

SCRIPT="$(abs_filename "$0")"

log() {
  if [ "$LOG" -eq 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S - ')$1" >> $LOG_FILE
  else
    echo "$1"
  fi
}

i_am_root() {
  if [ "$EUID" -ne 0 ]; then
    log "Please run as root."
    exit
  fi
}

xserver_up() {
  # Give Xserver 10 seconds to come up	
  sleep 5

  # shellcheck disable=SC2009,SC2126
  if [ "$(ps ax | grep '[x]init' | wc -l)" = "1" ]; then
    log "An Xserver is running."
  else
    log "Error: No xinit process found. Exiting."
    exit
  fi
}

install_svc() {
  log "Creating systemd services.."

  # If STARTX is set then we will add a service file
  # to systemd to launch the Xserver
  if [ -n "$STARTX" ]; then
cat << EOF > /etc/systemd/system/nvidia-overclock-startx.service
[Unit]
Description=StartX to overclock NVIDIA GPUs
After=runlevel4.target

[Service]
Type=oneshot
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/etc/X11/.Xauthority"
ExecStart=/usr/bin/startx

[Install]
WantedBy=nvidia-overclock.service
EOF
  fi

cat << EOF > /etc/systemd/system/nvidia-overclock.service
[Unit]
Description=Overclock NVIDIA GPUs at system start
After=runlevel4.target

[Service]
Type=oneshot
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/etc/X11/.Xauthority"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$SCRIPT auto -l -x

[Install]
WantedBy=multi-user.target
EOF

  chmod 664 /etc/systemd/system/nvidia-overclock-startx.service
  chmod 664 /etc/systemd/system/nvidia-overclock.service
  log "Reloading systemd daemon.."
  systemctl daemon-reload
  systemctl enable nvidia-overclock-startx.service
  systemctl enable nvidia-overclock.service
  log "Services installation complete."
}

uninstall_svc() {
  # Remove services
  if [ -f "/etc/systemd/system/nvidia-overclock-startx.service" ]; then
    log "Uninstalling nvidia-overclock-startx.service.."
    systemctl disable nvidia-overclock-startx.service
    rm /etc/systemd/system/nvidia-overclock-startx.service
    RELOAD_SYSTEMD=1
  else
    log "No nvidia-overclock-startx.service file exists to uninstall."
  fi

  if [ -f "/etc/systemd/system/nvidia-overclock.service" ]; then
    log "Uninstalling nvidia-overclock.service.."
    systemctl disable nvidia-overclock.service
    rm /etc/systemd/system/nvidia-overclock.service
    RELOAD_SYSTEMD=1
  else
    log "No nvidia-overclock.service file exists to uninstall."
  fi

  # Reload systemd
  if [ -n "$RELOAD_SYSTEMD" ]; then
    log "Reloading systemd daemon.."
    systemctl daemon-reload
    systemctl reset-failed
    log "Service uninstall complete."
  fi
}

create_Xwrapper_config() {
  # Preserve the existing Xwrapper.config file if it exists
  if [ ! -f "/etc/X11/Xwrapper.config.orig" ]; then
    if [ -f "/etc/X11/Xwrapper.config" ]; then
      mv /etc/X11/Xwrapper.config /etc/X11/Xwrapper.config.orig
    fi
  else
    # If an existing Xwrapper.config.orig file exists (even if it was 
    # created by us), do NOT overwrite as this could be an accidental run
    # to install the service again. Better to have the user manually verify
    # and move it themselves.
    log "Error: Unable to move /etc/X11/Xwrapper.config."
    log "The file /etc/X11/Xwrapper.config.orig already exists. Please move or rename it."
    log "Exiting to avoid overwriting the existing file."
    exit
  fi


# Create a custom /etc/X11/Xwrapper.config if it does not already exist
if [ ! -f "/etc/X11/Xwrapper.config" ]; then
cat << EOF > /etc/X11/Xwrapper.config
# Xwrapper.config (Debian X Window System server wrapper configuration file)
#
# This file was generated by nvidia-overclock.sh script to enable startx
# to be invoked from a non-console session at startup.
#
# The original file has been moved to /etc/X11/Xwrapper.config.orig
allowed_users=anybody
needs_root_rights=yes
EOF
fi
}

restore_Xwrapper_config() {
  if [ -f "/etc/X11/Xwrapper.config" ]; then
    # As a safety measure only overwrite config files that were created by nvidia-overclock.sh
    # shellcheck disable=SC2009,SC2126
    if [ "$(grep nvidia-overclock /etc/X11/Xwrapper.config | wc -l)" = "1" ]; then
      RESTORE_XWRAPPER=1
    else
      log "Existing /etc/X11/Xwrapper.config was not created by nvidia-overclock.sh."
      log "No restoration of the original file will be performed."
      return
    fi
  else
    RESTORE_XWRAPPER=1
  fi

  if [ -n "$RESTORE_XWRAPPER" ]; then
    if [ -f "/etc/X11/Xwrapper.config.orig" ]; then
      log "Found original Xwrapper.config file.  Restoring.."
      mv /etc/X11/Xwrapper.config.orig /etc/X11/Xwrapper.config
      log "Xwrapper.config file restored."
    else
      log "No original Xwrapper.config file found."
    fi
  fi
}

usage() {
cat << EOF
Usage:
  nvidia-overclock.sh [COMMAND]

Description:
  This script manages simple overclocking of NVIDIA Graphics cards on Linux.

  To use it, please perform the following steps:
  (1) Update the values in the overclock() function with values for your GPUs.
  (2) Install the script by changing to its directory and running:
 
      ./nvidia-overclock.sh install-svc -x

      This will install the service and use "startx" to automatically start
      XWindows.  If you already have XWindows installed and configured to run
      automatically on boot, then omit the -x option.
 
      ./nvidia-overclock.sh install-svc
 
  (3) Reboot the system and XWindows should start automatically with your GPUs
      set to the specified overclocked values.
 
  For the full documentation and detailed requirements, please read the 
  accompanying README.md file.

Commands:
  overclock
    Set the overclock values for the graphics card(s) defined in the overclock
    function.  No check is performed to verify if XWindows is running or if 
    logging is enabled.

  auto [-l] [-x]
    Check that XWindows is started if the -x is passed.  If XWindows is 
    started, then set the overclock values for the graphics cards(s) defined in
    the overclock function.  If -l is passed, then output will be logged to the
    file specified by LOG_FILE.

  install-svc [-x]
    Creates a systemd service to overclock the cards, installs, and enables it.
    If the -x option is passed, then it will create a custom Xwrapper.config
    file, so that "startx" can be used to automatically start XWindows on boot.

  uninstall-svc
    Removes the systemd service and restores the original Xwrapper.config file
    if it previously existed.

  help|--help|usage|--usage|?
    Display this help message.
EOF
}

case $1 in 
  overclock )
    # Set the overclock values for the graphics card(s).  
    # No check is performed for XWindows or logging.

    overclock
    ;;
  auto )
    # If -l parameter is passed then enable logging
    # If -x parameter is passed then check that Xwindows is running
    shift
    while getopts ":lx" OPTS; do
      case $OPTS in
        l ) LOG=1
	    shift
            ;;
        x ) xserver_up
	    shift
            ;;
      esac
    done

    overclock
    ;;
  install-svc )
    # Automatically creates a systemd service script
    # and installs the service so it will be run
    # everytime the system starts up.
		
    i_am_root

    # If -x parameter is passed then replace
		# the /etc/X11/Xwrapper.config file
    shift
    while getopts ":x" OPTS; do
      case $OPTS in
        x ) STARTX="/usr/bin/startx" && create_Xwrapper_config;;
      esac
    done

    install_svc
    ;;
  uninstall-svc )
    # Removes the systemd service
    i_am_root
    restore_Xwrapper_config
    uninstall_svc
    ;;
  help|--help|usage|--usage|\? )
    usage
    ;;
  * )
    usage
    ;;
esac
