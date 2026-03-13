#!/bin/bash
# Автоматизация для Lenovo G50-30 (Legacy BIOS Mode)

# 1. Форматирование
# ВАЖНО: Убедись, что /dev/sda1 — это основной раздел (ext4), а не FAT32.
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt

# 2. Установка системы
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode nano git

# 3. Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 4. Настройка внутри системы
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "ffeflin-laptop" > /etc/hostname

# Установка необходимых пакетов (убираем efibootmgr, добавляем grub)
pacman -S --noconfirm grub hyprland i3-wm kitty waybar NetworkManager

# Установка GRUB на сам диск (не на раздел!)
# Для Legacy BIOS установка идет на /dev/sda
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

echo "Установка завершена! Не забудь задать пароль: passwd"
EOF
