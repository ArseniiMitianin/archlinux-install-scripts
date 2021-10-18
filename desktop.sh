#!/bin/zsh

source functions.sh

desktop=$1
driver=$2

# Adding video driver packages
packages=(mesa)
case $driver in
    nvidia) packages+=(nvidia nvidia-utils nvidia-settings) ;;
    amdgpu) packages+=(xf86-video-amdgpu amdvlk) ;;
    intel)  packages+=(xf86-video-intel vulkan-intel) ;;
    vmware) packages+=(xf86-video-vmware) ;;
esac

# Adding packages for the desktop environment
packages+=(xf86-input-libinput xf86-input-elographics xf86-input-synaptics vivaldi vivaldi-ffmpeg-codecs)
case $desktop in
    gnome)
        packages+=(
            gnome gnome-tweaks gnome-shell-extensions gnome-software-packagekit-plugin
        )
        ;;
    kde)
        packages+=(
            plasma plasma-wayland-session sddm dolphin konsole kolourpaint elisa gwenview okular
            ktouch kcharselect discover libdbusmenu-glib libdbusmenu-gtk2
            libdbusmenu-gtk3 libdbusmenu-qt5 packagekit-qt5
        )

        if [[ $driver == 'nvidia' ]]; then packages+=(egl-wayland); fi
        ;;   
esac

# Install everything
pacman -S --noconfirm --needed ${packages[@]}
if [[ $desktop == 'gnome' ]]; then pacman -Rns --noconfirm epiphany; fi # Already have Vivaldi, no need for GNOME's browser

# Enabling the Display Manager
case $desktop in
    gnome)
        green "\nEnabling GNOME Display Manager\n\n"
        systemctl enable gdm.service &> /dev/null
        ;;
    kde)
        green "\nEnabling Simple Desktop Display Manager\n\n"
        systemctl enable sddm &> /dev/null
        ;;
esac
