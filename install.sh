#!/bin/bash
# Автоматизация для Lenovo G50-30

# 1. Форматирование (предполагается, что ты уже сделал разделы в cfdisk)
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/efi

# 2. Установка системы
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode nano git

# 3. Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 4. Настройка внутри системы
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "ffeflin-laptop" > /etc/hostname

# Настройка UKI
mkdir -p /etc/kernel
echo "root=PARTUUID=\$(blkid -s PARTUUID -o value /dev/sda2) rw quiet" > /etc/kernel/cmdline
sed -i 's|#default_uki="/vmlinuz-linux"|default_uki="/efi/EFI/Linux/arch-zen.efi"|' /etc/mkinitcpio.d/linux-zen.preset

mkdir -p /efi/EFI/Linux
mkinitcpio -P

# Загрузчик
pacman -S --noconfirm efibootmgr hyprland i3-wm kitty waybar NetworkManager
efibootmgr --create --disk /dev/sda --part 1 --label "Arch Zen" --loader 'EFI\Linux\arch-zen.efi' --unicode
systemctl enable NetworkManager

echo "Установка завершена! Введи 'passwd' для root и 'useradd' вручную."
EOF
