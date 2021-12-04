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

if [[ -n $selected_desktop ]]; then
    clear

    # Grabbing the information about the graphics card
    vga_device=$(lspci | grep -E '(VGA|3D|2D)')

    # Checking the GPU vendor and adding packages
    packages=(mesa)
    case $vga_device in
        *NVIDIA*  ) 
            green 'Found an Nvidia graphics card!\n\n'
            packages+=(nvidia nvidia-utils lib32-nvidia-utils nvidia-settings) ;;
        *AMD/ATI* )
            red 'Found an AMD graphics card!\n\n'
            packages+=(xf86-video-amdgpu vulkan-radeon amdvlk)                 ;;
        *Intel*   )
            blue 'Found an Intel graphics card!\n\n'
            packages+=(xf86-video-intel vulkan-intel)                          ;;
        *VMware*  )
            cyan 'Found a graphics adapter for virtual machines!\n\n'
            packages+=(xf86-video-vmware)                                      ;;
    esac

    # Adding packages for the desktop environment
    packages+=(xf86-input-libinput xf86-input-elographics xf86-input-synaptics vivaldi vivaldi-ffmpeg-codecs)
    case $selected_desktop in
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

            if [[ $vga_device =~ 'NVIDIA' ]]; then packages+=(egl-wayland); fi
            ;;   
    esac

    # Install everything
    pacman -S --noconfirm --needed ${packages[@]}
    if [[ $selected_desktop == 'gnome' ]]; then pacman -Rns --noconfirm epiphany; fi # Already have Vivaldi, no need for GNOME's browser

    # Enabling the Display Manager
    case $selected_desktop in
        gnome)
            green "\nEnabling GNOME Display Manager\n\n"
            systemctl enable gdm.service &> /dev/null
            ;;
        kde)
            green "\nEnabling Simple Desktop Display Manager\n\n"
            systemctl enable sddm &> /dev/null
            ;;
    esac

    if [[ $vga_device =~ 'NVIDIA' ]]; then
        cyan "\nNvidia driver installed. Configuring\n"
        
        green "Enabling DRM kernel mode setting\n"
        sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\" *$/ nvidia-drm.modeset=1\"/" /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg

        green "\nAdding kernel modules to Initramfs\n"
        sed -i "/^MODULES=/ s/)$/nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
        mkinitcpio -P

        green "\nAdding a Pacman hook\n"
        mkdir /etc/pacman.d/hooks
        cat << EOF | sed -e 's/^ *//' > /etc/pacman.d/hooks/nvidia.hook;
            [Trigger]
            Operation=Install
            Operation=Upgrade
            Operation=Remove
            Type=Package
            Target=nvidia

            [Action]
            Description=Update Nvidia modules in Initramfs
            Depends=mkinitcpio
            When=PostTransaction
            Exec=/usr/bin/mkinitcpio -P
EOF
    fi
else
    clear
    cyan "No desktop selected. Skipping.\n\n"
fi
