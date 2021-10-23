#!/bin/zsh

########################################################################################################################
# COLORING FUNCTIONS                                                        Having some colors wouldn't hurt for sure. #
########################################################################################################################
function white  { tput sgr 0; }
function red    { tput bold; tput setaf 1; echo -en $1; white; }
function green  { tput bold; tput setaf 2; echo -en $1; white; }
function yellow { tput bold; tput setaf 3; echo -en $1; white; }
function cyan   { tput bold; tput setaf 6; echo -en $1; white; }


########################################################################################################################
# HELPER FUNCTIONS                                                                                                     #
########################################################################################################################
function cpu {
    if [[ $(lscpu | grep GenuineIntel) ]]; then
        echo -n "intel"
    elif [[ $(lscpu | grep AuthenticAMD) ]]; then
        echo -n "amd"
    fi
}

function configure_pacman {
    cyan "Configuring Pacman\n"
    green "  --> Enabling colored output\n";          sed '/Color/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling verbose package listing\n"; sed '/VerbosePkgLists/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling parallel downloads\n";      sed '/ParallelDownloads/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling multilib repo\n";           sed '93,94 s/^#//' -i /etc/pacman.conf
}

function launch {
    local filename=$1
    local arg1=$2
    local arg2=$3

    cp $HOME/$filename /mnt
    chmod +x /mnt/$filename
    arch-chroot /mnt ./$filename $arg1 $arg2
    rm "/mnt/$filename"
}

function cancel {
    local status_code=$1

    red "User pressed '"
    case $status_code in
        1)   red "Cancel" ;;
        255) red "Esc"    ;;
    esac
    red "'. Installation aborted.\n\n"

    exit 1
}

function confirm {
    local status_code=$1

    clear

    if [[ ! $status_code -eq 0 ]]; then
        cancel $status_code
    fi
}

function continue_or_cancel {
    local status_code=$1
    local value=$2
    local error_text=$3

    clear

    if [[ ! $status_code -eq 0 ]]; then
        cancel $status_code
    elif [[ -z $value ]]; then
        red "$error_text. Installation aborted.\n\n"
        exit 1
    fi
}
