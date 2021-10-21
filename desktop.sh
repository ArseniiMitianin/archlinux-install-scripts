#!/bin/zsh

source functions.sh

desktops=(
    gnome 'GNOME Desktop (X.Org + Wayland)' 'off'
    kde 'KDE (X.Org + Wayland)' 'off'
)

selected_desktop=$(
    dialog --keep-tite --stdout \
    --backtitle "Arch Linux Installer" \
    --title "Desktop Installation" \
    --radiolist "Select a desktop environment you'd like to install. If you choose none, this section will be skipped." \
    20 61 10 \
    ${desktops[@]}
)

if [[ ! -z $selected_desktop ]]; then
    drivers=(
        nvidia 'Proprietary NVidia graphics driver' 'off'
        amdgpu 'Open-source AMD graphics driver' 'off'
        intel  'Open-source Intel graphics driver' 'off'
        vmware 'Open-source graphics driver for virtual machines' 'off'
    )

    declare selected_driver
    until [[ ! -z $selected_driver ]]; do
        selected_driver=$(
            dialog --keep-tite --stdout --nocancel \
            --backtitle "Arch Linux Installer" \
            --title "Desktop Installation" \
            --radiolist "Select a driver for your GPU." \
            20 67 10 \
            ${drivers[@]}
        )
    done

    # Adding video driver packages
    packages=(mesa)
    case $selected_driver in
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
                libdbusmenu-gtk3 libdbusmenu-qt5 packagekit-qt5 xorg-xrandr
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
else
    clear
    cyan "No desktop selected. Skipping.\n\n"
fi
