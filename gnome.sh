#!/bin/zsh

# Colors
function white  { tput sgr 0; }
function cyan   { tput setaf 6; echo -en $1; white; }
function green  { tput setaf 2; echo -en $1; white; }
function yellow { tput setaf 3; echo -en $1; white; }

green "\nInstalling GNOME\n"

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
    n) packages+=('nvidia' 'nvidia-utils' 'nvidia-settings') ;;
    i) packages+=('mesa' 'xf86-video-intel' 'vulkan-intel') ;;
    v) packages+=('mesa' 'xf86-video-vmware') ;;
esac

# Add GNOME Packages
packages+=(
    'gnome' 'gnome-tweaks' 'gnome-shell-extensions' 'gnome-software-packagekit-plugin' 
    'vivaldi' 'vivaldi-ffmpeg-codecs'
)

# Install and enable stuff
pacman -S $(echo ${packages[@]})
pacman -Rns epiphany
green "\n  --> Enabling GNOME Display Manager\n"
systemctl enable gdm.service
