#!/usr/bin/env bash

##########################
## Fedora Config Script ##
##########################
set -euo pipefail

#############
# Variables #
#############
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGE_FILE="$SCRIPT_DIR/fedora_packages.txt"
FLATPAK_FILE="$SCRIPT_DIR/flatpak_packages.txt"
COPR_FILE="$SCRIPT_DIR/fedora_copr.txt"
RPM_DIR="$SCRIPT_DIR/third_party"
REAL_USER="${SUDO_USER:-$USER}"
USER_ID=$(id -u "$REAL_USER")

#######
# Log #
#######
LOG_FILE="$SCRIPT_DIR/install_$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

##########
# Checks #
##########

# Fedora detection
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ ! "$ID" = "fedora" ]; then
        echo -e "\e[31m\e[01mThis is not Fedora Linux (Distribution: $ID)"'\033[0m'
        read -p "Press enter to exit"
        exit 1
    fi
else
    echo -e "\e[31m\e[01mUnable to determine distribution"'\033[0m'
    read -p "Press enter to exit "
    exit 2
fi

# Root detection
if [[ $EUID != 0 ]]
then
   echo "Please launch this script as root"
   exit 1
fi

#############
# Functions #
#############

system_upgrades () {
		echo -e "\033[1;34m---------- SYSTEM UPGRADES ----------\033[0m"
		dnf upgrade -y --refresh
}

rpmfusion () {
	while true; do
		read -p "Do you want to install the rpmfusion repositories? (yes/no) " rpmfusion
		if [ "$rpmfusion" = "yes" ] || [ "$rpmfusion" = "no" ]; then
			break
		else
			echo "Please answer yes or no"
		fi
	done
	if [[ "$rpmfusion" == "yes" ]] ; then
		echo -e "\033[1;34m----- RPMFUSION REPOSITORIES -----\033[0m"
		dnf install -y --nogpgcheck https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && dnf install -y rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data && dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted
	fi
}

fedora_packages () {
    echo -e "\033[1;34m---- FEDORA PACKAGES -----\033[0m"
    dnf install -y dnf-plugins-core
    if [[ ! -f "$PACKAGE_FILE" ]]; then
		echo "No package list found at $PACKAGE_FILE"
        return
    fi
    if [[ ! -f "$COPR_FILE" ]]; then
		echo "No copr list found at $COPR_FILE"
        return
    fi

    mapfile -t PACKAGES < <(
        grep -Ev '^\s*#|^\s*$' "$PACKAGE_FILE"
    )
    mapfile -t COPR < <(
        grep -Ev '^\s*#|^\s*$' "$COPR_FILE"
    )

    if (( ${#PACKAGES[@]} == 0 )); then
        echo "No packages to install."
        return
    fi
    
    for repo in "${COPR[@]}"; do
        dnf copr enable -y "$repo" || echo "Warning: Unable to enable the COPR $repo"
    done
    dnf install -y "${PACKAGES[@]}"
}

flatpak_packages () {
    if [[ ! -f "$FLATPAK_FILE" ]]; then
        echo "No Flatpak list found at $FLATPAK_FILE"
        return
    fi

    mapfile -t FLATPAKS < <(
        grep -Ev '^\s*#|^\s*$' "$FLATPAK_FILE"
    )

    if (( ${#FLATPAKS[@]} == 0 )); then
        echo "No Flatpaks to install."
        return
    fi

    if ! flatpak remotes | grep -q flathub; then
         flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    flatpak update --appstream
    flatpak install -y flathub "${FLATPAKS[@]}"
}

gnome_customization () {
    if ! command -v gnome-shell &> /dev/null; then
        echo "Not running GNOME desktop environment. Skipping GNOME customizations."
        return 0
    fi
    if [[ "$REAL_USER" == "root" ]]; then
        echo "Warning : The GNOME customizations will be applied to root (probably not your typical user)"
    fi
	while true; do
		read -p "Do you want to apply GNOME customizations? (yes/no) " gnome_customize
		if [ "$gnome_customize" = "yes" ] || [ "$gnome_customize" = "no" ]; then
			break
		else
			echo "Please answer yes or no"
		fi
	done
	if [[ "$gnome_customize" == "yes" ]] ; then
		echo -e "\033[1;34m----- GNOME CUSTOMIZATIONS -----\033[0m"
		# Install extensions
		dnf install gnome-shell-extension-appindicator gnome-shell-extension-dash-to-dock gnome-shell-extension-gsconnect -y
		dnf install adw-gtk3-theme -y

		# Dconf customisations
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.interface clock-show-date true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.interface clock-show-seconds true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.interface clock-show-weekday true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.mutter check-alive-timeout 60000
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.privacy report-technical-problems false
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.desktop.privacy send-software-usage-stats false
		# Nautilus
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.nautilus.list-view use-tree-view true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gtk.Settings.FileChooser sort-directories-first true
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true
		# Gnome Text Editor
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.TextEditor restore-session false
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.TextEditor show-line-numbers true
		# Ptyxis
		sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" gsettings set org.gnome.Ptyxis restore-session false

		echo "GNOME customizations applied successfully!"
		echo "Some changes require you to log in again to take effect."
	fi
}

third_party () {
	if [[ ! -d "$RPM_DIR" ]]; then
		echo "No RPM dir found at $RPM_DIR"
		return
        fi
	echo -e "\033[1;34m---- THIRD PARTY PACKAGES -----\033[0m"
	if compgen -G "$RPM_DIR/*.rpm" > /dev/null; then
	    dnf install -y "$RPM_DIR"/*.rpm
	else
	    echo "No third-party RPMs to install."
	fi
}

nvidia_driver () {
	while true; do
		read -p "Do you want to install the nonfree Nvidia driver? (yes/no) " nvidia_driver
		if [ "$nvidia_driver" = "yes" ] || [ "$nvidia_driver" = "no" ]; then
			break
		else
			echo "Please answer yes or no"
		fi
	done
	if [[ "$nvidia_driver" == "yes" ]] ; then
		echo -e "\033[1;34m----- Nvidia Driver -----\033[0m"
			dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y
	fi
}

codecs () {
	while true; do
		read -p "Do you want to install codecs? (yes/no) " codecs
		if [ "$codecs" = "yes" ] || [ "$codecs" = "no" ]; then
			break
		else
			echo "Please answer yes or no"
		fi
	done
	if [[ "$codecs" == "yes" ]] ; then
		echo -e "\033[1;34m----- CODECS -----\033[0m"
		dnf config-manager setopt fedora-cisco-openh264.enabled=1
		dnf swap ffmpeg-free ffmpeg --allowerasing -y
		dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
	fi
}

###############
# Main Script #
###############
cat << 'EOF'
        ,'''''.
       |   ,.  |     ___                     _                 _____                        .   
       |  |  '_'   .'   \   __.  , __     ___/ `   ___.       (        ___  .___  ` \,___, _/_  
  ,....|  |..      |      .'   \ |'  `.  /   | | .'   `        `--.  .'   ` /   \ | |    \  |   
.'  ,_;|   ..'     |      |    | |    | ,'   | | |    |           |  |      |   ' | |    |  |   
|  |   |  |         `.__,  `._.' /    | `___,' /  `---|      \___.'   `._.' /     / |`---'  \__/
|  ',_,'  |                                  `    \___/                             \           
 '.     ,'
   '''''
EOF
echo -e '\033[1m\033[4m'"This script does, in order:"'\033[0m'

echo -e "\033[1m1. System Upgrades"
echo "2. Enable rpmfusion repositories"
echo "3. Install fedora packages you want"
echo "4. Install flatpaks you want"
echo "5. Install third party packages you want"
echo "6. Install the nvidia driver if you want"
echo "7. Install codecs if you want"
echo -e "8. Apply GNOME customizations if you want\033[0m"

echo -e '\033[1m' ; read -p "The script will start ! Go ? " ; echo -e '\033[0m'
system_upgrades
rpmfusion
fedora_packages
flatpak_packages
third_party
nvidia_driver
codecs
gnome_customization
echo -e "\033[1;35m---------- End of script ! Goodbye ! ----------"
exit 0
