FROM archlinux:latest
RUN echo 'Server = https://mirror.sjtu.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
RUN pacman -Syu --noconfirm && pacman -S --noconfirm make riscv64-elf-gcc riscv64-elf-newlib
