#!/bin/zsh

# Colors
function white  { tput sgr 0; }
function cyan   { tput setaf 6; echo -en $1; white; }
function green  { tput setaf 2; echo -en $1; white; }
function yellow { tput setaf 3; echo -en $1; white; }

function session {
    if [[ $1 == 'wayland' ]]; then
        echo -n 'a Wayland'
    elif [[ $1 == 'xorg' ]]; then
        echo -n 'an X.Org'
    fi
}

green "\nInstalling KDE Plasma with $(session $1) session\n"

# Prepare packages for video
yellow "\nWhich video driver to install?\n"
green "  --> [a] AMD\n"
green "  --> [n] NVidia (proprietary)\n" # Not fully operational for now.
green "  --> [i] Intel\n"
green "  --> [v] VMWare\n"
echo -n "> "
read video_driver

packages=()

case $video_driver in
    a) packages+=('mesa' 'xf86-video-amdgpu' 'amdvlk') ;;
    n) packages+=('nvidia' 'nvidia-utils') ;;
    i) packages+=('mesa' 'xf86-video-intel' 'vulkan-intel') ;;
    v) packages+=('mesa' 'xf86-video-vmware') ;;
esac

# Add KDE Plasma Packages
packages+=(
    'plasma' 'sddm' 'dolphin' 'konsole' 'kolourpaint' 'elisa' 'gwenview' 'okular' 
    'ktouch' 'kcharselect' 'discover' 'vivaldi' 'vivaldi-ffmpeg-codecs' 'libdbusmenu-glib' 
    'libdbusmenu-gtk2' 'libdbusmenu-gtk3' 'libdbusmenu-qt5' 'packagekit-qt5'
)

# Add Wayland packages, if necessary
if [[ $1 == 'wayland' ]]; then 
    packages+=('plasma-wayland-session')
    if [[ $video_driver == 'n' ]]; then packages+=('egl-wayland'); fi
fi

# Install and enable stuff
pacman -S $(echo ${packages[@]})
green "\n  --> Enabling Simple Desktop Display Manager\n"
systemctl enable sddm
