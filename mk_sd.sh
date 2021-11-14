#!/bin/bash

#  https://fedoraproject.org/wiki/Architectures/RISC-V/Allwinner

#dd if=/dev/zero of=sd.img bs=1M count=512

# p1 first sector 65536 16M

# sd.img1          65536   98303   32768   16M 83 Linux
# sd.img2          98304  303103  204800  100M 83 Linux
# sd.img3         303104 1048575  745472  364M 83 Linux

init_image() {
    rm -f sd.img
    xz -d -k sd.img.xz
}

#sudo losetup /dev/loop0 sd.img
#sudo partprobe  /dev/loop0
#sudo mkfs.fat /dev/loop0p1
#sudo mkfs.ext4 /dev/loop0p2
#sudo mkfs.ext4 /dev/loop0p3

# CONFIG_SYS_BOOTM_LEN
# Image too large: increase CONFIG_SYS_BOOTM_LEN


# ls mmc 0:1
# load mmc 0:1 0x50000000 kernel.itb
# setenv bootargs 'earlyprintk=sunxi-uart,0x02500000 console=ttyS0,115200 console=tty0 loglevel=8'
#bootargs=earlyprintk=sunxi-uart,0x02500000 console=ttyS0,115200 console=tty0 loglevel=8
# bootm 0x50000000#DevelBoard2

dummy() {
    dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=sd.img bs=512 seek=16 conv=notrunc

    
}


u_boot() {
    make -C u-boot CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv u-boot.bin u-boot.dtb -j20 
    
    mkdir toc_build
    
    cp config/toc1.cfg toc_build
    
    cp opensbi/build/platform/generic/firmware/fw_dynamic.bin toc_build
    cp u-boot/u-boot.dtb toc_build
    cp u-boot/u-boot.bin toc_build
    
    pushd toc_build
    
    ../u-boot/tools/mkimage -T sunxi_toc1 -d toc1.cfg  u-boot.toc1
     
    popd
    
    dd if=toc_build/u-boot.toc1 of=sd.img bs=512 seek=32800 conv=notrunc
}

kernel_build() {
    
    #make CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv nezha_fedora_defconfig
    #make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv menuconfig
    #make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv -j20 #zimage
    
    mkdir -p kernel_build
    cp linux/arch/riscv/boot/Image kernel_build
    cp linux/arch/riscv/boot/dts/allwinner/allwinner-d1-nezha-kit.dtb kernel_build
    cp linux/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb kernel_build
    cp Fedora/boot/aw_nezha_d1_2G.dtb kernel_build
    cp Fedora/boot/vmlinux-5.4.61+ kernel_build
    cp Fedora/boot/vmlinuz-5.10.6-200.0.riscv64.fc33.riscv64 kernel_build
    
    cp config/kernel.its kernel_build
    
    make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv INSTALL_PATH=../kernel_build zinstall
    
    pushd kernel_build
    mkimage -f kernel.its kernel.itb
    popd
    
    dev=$(losetup -f)
    
    sudo losetup $dev sd.img
    sudo partprobe  $dev
    sudo mount $dev"p1" /mnt/image
    sudo cp kernel_build/kernel.itb /mnt/image
    sudo cp config/uEnv.txt /mnt/image 
    ls /mnt/image
    df -h /mnt/image
    sudo umount /mnt/image
    sudo losetup -d $dev
    
    
}

#u_boot
kernel_build

