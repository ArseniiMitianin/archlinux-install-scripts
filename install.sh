#!/bin/zsh

########################################################################################################################
# !!! DISCLAIMER !!!                                                                                                   #
#                                                                                                                      #
# This script is only suitable for a scenario where you're not planning to dual-boot!                                  #    
# If the selected disk has any other OS, it WILL be wiped.                                                             #
#                                                                                                                      #
# You've been warned.                                                                                                  # 
########################################################################################################################

source functions.sh

########################################################################################################################
# MAIN SCRIPT                                                                                                          #
########################################################################################################################

# Check which boot mode is used
ls /sys/firmware/efi/efivars &> /dev/null
is_uefi=$?

# Connect to the Internet
if [[ $(ip a | grep -Pz 'enp.*:(.*\n){2}.*inet') ]]; then
    green "\nFound an Ethernet connection!\n\n"
elif [[ $(ip a | grep -Pz '(wlan|wlp).*:(.*\n){2}.*inet') ]]; then
    green "\nFound a Wi-Fi connection!\n\n"
elif [[ $(ip a | egrep 'enp.*:.*state DOWN') && $(ip a | egrep '(wlan|wlp).*:.*state DOWN') ]]; then
    green "Found a Wi-Fi device on your machine\n"
    yellow "Select a network device\n"
    iwctl device list
    echo -n "> "
    read net_device

    yellow "\nWhich network to connect to?\n"
    iwctl station $net_device get-networks
    echo -n "> "
    read network

    if iwctl station ${net_device} connect ${network}; then
        green "\nSuccessfully connected to ${network}!\n\n"
    fi
else
    red "\nYou need to connect to the Internet first!\n\n"
    exit 1
fi

# Fetch fresh package database files
configure_pacman
pacman -Sy

# Install the `dialog` utility
if [[ -z $(pacman -Qqs ^dialog) ]]; then
    green "\nInstalling 'dialog'...\n\n"
    pacman -Sq --noconfirm --needed dialog
fi

# Put up a disclaimer, just in case
dialog --colors --keep-tite --stdout \
    --backtitle "Arch Linux Installer" \
    --title "\Z1!!! DISCLAIMER !!!\Zn" \
    --yesno "This script is suitable to use only if you're not planning to dual-boot. \
Otherwise, any other operating system you have installed on a disk you'll have selected \Z1WILL be entirely wiped\Zn! \
\n\nAre you sure you want to continue?" \
    10 61
confirm $?

# Prepare disk info for `dialog`
disks=()
lsblk -ndPo PATH,MODEL,SIZE,VENDOR,TYPE | \
    grep disk | \
    awk -F'"' '{printf $2 "\t"; gsub(/ /, "", $8); printf $8 " "; printf $4 ", "; printf "Size: " $6 "\n"}' | \
    while IFS=$'\t' read -r path details; do
    # ^ Prints out disk info in the following format: /dev/sda<TAB>VENDOR MODEL, Size: SIZE
    
        # Arguments for dialog radiolist entries: tag, item, status. The `tag` is used as the resulting value.
        disks+=($path $details 'off')
    done

# This way the script won't throw a 'command not found' error
# I don't know why that happens
source /etc/profile

# Drive selection
device=$(
    dialog --keep-tite --stdout \
    --backtitle "Arch Linux Installer" \
    --title "System Installation" \
    --radiolist "The operating system will be installed on the disk you've selected." \
    20 61 10 \
    ${disks[@]}
)
disk_select_status=$?

continue_or_cancel $disk_select_status "$device" "No disk was selected"
green "Disk selected: $device\n\n"

cyan "Synchronizing your clock with the Internet\n"
timedatectl set-ntp true # Synchronize the clock with the Internet

# Partitioning the drive
cyan "Partitioning your drive\n"
if [[ $is_uefi -eq 0 ]]; then
    green "  --> The system is booted in UEFI mode. Creating a GPT partition scheme\n"
    parted --script $device \
        mklabel gpt \
        mkpart "boot" fat32 1MiB 501MiB \
        set 1 esp on \
        mkpart "swap" linux-swap 501MiB 16.5GiB \
        mkpart "root" ext4 16.5GiB 100%
else
    green "  --> The system is booted in BIOS mode. Creating an MBR partition scheme\n"
    parted --script $device \
        mklabel msdos \
        mkpart primary ext4 1MiB 501MiB \
        set 1 boot on \
        mkpart primary linux-swap 501MiB 16.5GiB \
        mkpart primary ext4 16.5GiB 100%
fi

# Formatting partitions
cyan "Formatting partitions\n"
mkfs.fat -F32 "${device}1" &> /dev/null
mkswap "${device}2" &> /dev/null
swapon "${device}2" &> /dev/null
mkfs.ext4 "${device}3" &> /dev/null

# Mounting partitions
cyan "Mounting partitions\n"
mount "${device}3" /mnt
mkdir /mnt/boot
mount "${device}1" /mnt/boot

# Installing
packages=(
    base base-devel linux linux-firmware linux-headers $(cpu)-ucode man-db man-pages texinfo
    networkmanager grub mtools dosfstools neovim git zsh bat wget ntfs-3g
)
if [[ $is_uefi -eq 0 ]]; then packages+=(efibootmgr); fi

pacstrap /mnt ${packages[@]}

cyan "\nGenerating the file system table\n"
genfstab -U /mnt >> /mnt/etc/fstab # Generate the file system table


########################################################################################################################
# CONFIGURATION AND DESKTOP INSTALLATION                                                                               #
########################################################################################################################

# Launch the configuration script
cp functions.sh /mnt
launch config.sh $device $is_uefi


# Installing a DE
desktops=(
    gnome 'GNOME Desktop (X.Org + Wayland)' 'off'
    kde 'KDE (X.Org + Wayland)' 'off'
)

selected_desktops=$(
    dialog --keep-tite --stdout \
    --backtitle "Arch Linux Installer" \
    --title "System Installation" \
    --checklist "Select any desktop environments you'd like to install. If you choose none, this section will be skipped" \
    20 61 10 \
    ${desktops[@]}
)

if [[ ! -z $selected_desktops ]]; then
    echo $selected_desktops | read -A desktop_list

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
            --title "System Installation" \
            --radiolist "Select a driver for your GPU." \
            20 67 10 \
            ${drivers[@]}
        )
    done

    for desktop in $selected_desktops; do
        launch desktop.sh $desktop $selected_driver
    done
else
    clear
    cyan "No desktop selected. Skipping.\n\n"
fi

########################################################################################################################
# DONE!                                                                                                                #
########################################################################################################################
cyan "\nCleaning up\n"
rm /mnt/functions.sh
arch-chroot /mnt pacman -Rns --noconfirm dialog &> /dev/null # Uninstall `dialog` from the new system, it's no longer needed.

cyan "Unmounting partitions\n"
umount -R /mnt

green "\nInstallation complete! You can now "; yellow "reboot"; green " your machine.\n\n"
