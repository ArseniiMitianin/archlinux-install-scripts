# Personal Install scripts
Currently these scripts can do a base install Arch Linux with my preferred configs:
- Hard drive:
    - `/boot`: 500 MiB (UEFI - FAT32, BIOS - Ext4)
    - Swap: 16 GiB (needed for suspend-on-disk/hibernation)
    - `/`: Rest of free space Ext4
- Shell: Zsh

Optional desktop install available.

## TODOs
### Features
- [ ] Interaction through TUI windows with `dialog`

### Things that are definitely needed
- [x] Desktops (X.Org + Wayland):
  - [x] KDE
  - [x] GNOME
- [ ] Programs for everyday use
- [ ] Development programs

### Optional stuff
- [ ] Gaming packages (Steam, Wine, Lutris, etc. etc.?)
- [ ] I'll think of something else later...
