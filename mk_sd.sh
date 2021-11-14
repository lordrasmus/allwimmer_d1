#!/bin/bash

#  https://fedoraproject.org/wiki/Architectures/RISC-V/Allwinner

prepare(){
    git submodule init
    git submodule update
    
    sudo apt install autopoint
}


#dd if=/dev/zero of=sd.img bs=1M count=512

# p1 first sector 65536 16M

# sd.img1          65536   98303   32768   16M 83 Linux
# sd.img2          98304  303103  204800  100M 83 Linux
# sd.img3         303104 1048575  745472  364M 83 Linux

init_image() {
    rm -f sd.img
    xz -d -k sd.img.xz
}

init_sd_card(){
    dd if=/dev/zero of=sd.img bs=1M count=512
    sfdisk sd.img < config/sd_card.parts > /dev/null 
    
    dev=$(losetup -f)
    sudo losetup $dev sd.img
    sudo partprobe  $dev
    sudo mkfs.fat  /dev/loop0p1 > /dev/null 
    sudo mkfs.ext4 /dev/loop0p2 > /dev/null 2>&1
    sudo mkfs.ext4 /dev/loop0p3 > /dev/null 2>&1
    sudo losetup -d $dev
    
}

#sudo losetup /dev/loop0 sd.img
#sudo partprobe  /dev/loop0
#
#sudo mkfs.ext4 /dev/loop0p2
#sudo mkfs.ext4 /dev/loop0p3

# CONFIG_SYS_BOOTM_LEN
# Image too large: increase CONFIG_SYS_BOOTM_LEN


# ls mmc 0:1
# load mmc 0:1 0x50000000 kernel.itb
# load mmc 0:1 0x58000000 /EFI/grubriscv64.efi
# bootefi 0x58000000
# setenv bootargs 'earlyprintk=sunxi-uart,0x02500000 console=ttyS0,115200 console=tty0 loglevel=8'
#bootargs=earlyprintk=sunxi-uart,0x02500000 console=ttyS0,115200 console=tty0 loglevel=8
# bootm 0x50000000#DevelBoard2

spl(){
    
    if [ ! -e sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin ] ; then
    
        pushd sun20i_d1_spl
        git checkout origin/mainline
        make CROSS_COMPILE=riscv64-linux-gnu- p=sun20iw1p1 mmc -j20
        popd
        
    fi
    
    dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=sd.img bs=512 seek=16 conv=notrunc > /dev/null 2>&1
}

opensbi(){
    CROSS_COMPILE=riscv64-linux-gnu- PLATFORM=generic FW_PIC=y make -C opensbi -j20
}

u_boot() {
    
    if [ ! -e u-boot/u-boot.bin ] ; then
        pushd u-boot
        git checkout origin/allwinner_d1
        make CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv nezha_defconfig
        make CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv u-boot.bin u-boot.dtb -j20 
        popd
    fi
    
    mkdir toc_build
    
    cp config/toc1.cfg toc_build
    
    cp opensbi/build/platform/generic/firmware/fw_dynamic.bin toc_build
    cp u-boot/u-boot.dtb toc_build
    cp u-boot/u-boot.bin toc_build
    
    pushd toc_build
    
    ../u-boot/tools/mkimage -T sunxi_toc1 -d toc1.cfg  u-boot.toc1
     
    popd
    
    dd if=toc_build/u-boot.toc1 of=sd.img bs=512 seek=32800 conv=notrunc > /dev/null 2>&1
    
    dev=$(losetup -f)
    sudo losetup $dev sd.img
    sudo partprobe  $dev
    sudo mount $dev"p1" /mnt/image
    sudo cp config/uEnv.txt /mnt/image 
    ls /mnt/image
    df -h /mnt/image
    sudo umount /mnt/image
    sudo losetup -d $dev
}

grub(){
    
    pushd grub
    git remote add github.com_tekkamanninja https://github.com/tekkamanninja/grub.git
    git fetch github.com_tekkamanninja
    git checkout github.com_tekkamanninja/riscv_devel_Nikita_V2
    popd
    
    pushd grub

    mkdir -p grub_install
    #setup build env
    GRUB_INSTALL_DIR=$(pwd)"/grub_install"

    GRUB_BUILD_CONFIG="--target=riscv64-linux-gnu --with-platform=efi --prefix=${GRUB_INSTALL_DIR}"

    GRUB_DEFAULT_CFG_RISCV=$(pwd)"/../config/default.cfg"
    GRUB_BINARY_NAME_RISCV=grubriscv64.efi
    GRUB_BINARY_FORMAT_RISCV=riscv64-efi
    GRUB_PREFIX_DIR_RISCV=efi
    GRUB_UEFI_IMAGE_MODULES_RISCV="acpi adler32 affs afs afsplitter all_video archelp bfs bitmap bitmap_scale blocklist boot bswap_test btrfs bufio cat cbfs chain cmdline_cat_test cmp cmp_test configfile cpio_be cpio crc64 cryptodisk crypto ctz_test datehook date datetime diskfilter disk div div_test dm_nv echo efifwsetup efi_gop efinet elf eval exfat exfctest ext2 extcmd f2fs fat fdt file font fshelp functional_test gcry_arcfour gcry_blowfish gcry_camellia gcry_cast5 gcry_crc gcry_des gcry_dsa gcry_idea gcry_md4 gcry_md5 gcry_rfc2268 gcry_rijndael gcry_rmd160 gcry_rsa gcry_seed gcry_serpent gcry_sha1 gcry_sha256 gcry_sha512 gcry_tiger gcry_twofish gcry_whirlpool geli gettext gfxmenu gfxterm_background gfxterm_menu gfxterm gptsync gzio halt hashsum hello help hexdump hfs hfspluscomp hfsplus http iso9660 jfs jpeg json keystatus ldm linux loadenv loopback lsacpi lsefimmap lsefi lsefisystab lsmmap ls lssal luks2 luks lvm lzopio macbless macho mdraid09_be mdraid09 mdraid1x memdisk memrw minicmd minix2_be minix2 minix3_be minix3 minix_be minix mmap mpi msdospart mul_test net newc nilfs2 normal ntfscomp ntfs odc offsetio part_acorn part_amiga part_apple part_bsd part_dfly part_dvh part_gpt part_msdos part_plan part_sun part_sunpc parttool password password_pbkdf2 pbkdf2 pbkdf2_test pgp png priority_queue probe procfs progress raid5rec raid6rec read reboot regexp reiserfs romfs scsi search_fs_file search_fs_uuid search_label search serial setjmp setjmp_test sfs shift_test signature_test sleep sleep_test smbios squash4 strtoull_test syslinuxcfg tar terminal terminfo test_blockarg testload test testspeed tftp tga time tpm trig tr true udf ufs1_be ufs1 ufs2 video_colors video_fb videoinfo video videotest_checksum videotest xfs xnu_uuid xnu_uuid_test xzio zfscrypt zfsinfo zfs zstd "
    GRUB_MKIMAGE_ARG_RISCV="-c $GRUB_DEFAULT_CFG_RISCV $GRUB_UEFI_IMAGE_MODULES_RISCV"

    echo $GRUB_DEFAULT_CFG_RISCV

    if [ ! -e grub-mkimage ] ; then
        #bootstrap, download gunlib...
        ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./bootstrap
        
        
        #auto generate the config files
        ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./autogen.sh
        #auto config and generate Makefile
        if [ ! -e Makefile ] ; then
            ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./configure  ${GRUB_BUILD_CONFIG}
        fi
        #build and install to ${RISCV_ROOTFS}
        ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- make -j20
    fi
    
    if [ ! -e grub_install/grubriscv64.efi ] ; then
        ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- make install
    fi
    

    #make executable efi file 
    pushd ${GRUB_INSTALL_DIR}
    ./bin/grub-mkimage  \
                       -o ${GRUB_BINARY_NAME_RISCV} \
                       -O  ${GRUB_BINARY_FORMAT_RISCV} \
                       -p ${GRUB_PREFIX_DIR_RISCV}  \
                       ${GRUB_MKIMAGE_ARG_RISCV} #-v
    popd
    
    dev=$(losetup -f)
    echo $dev
    sudo losetup $dev ../sd.img
    sudo partprobe  $dev
    sudo mount $dev"p1" /mnt/image
    sudo mkdir -p /mnt/image/EFI/
    sudo cp grub_install/grubriscv64.efi /mnt/image/EFI
    ls /mnt/image
    sudo umount /mnt/image
    sudo losetup -d $dev

    popd
}

kernel_build() {
    
    pushd linux
    git checkout origin/allwinner_nezha_d1_devel_with_smaeul_patch
    popd

    if [ ! -e linux/.config ] ; then
        #make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv nezha_fedora_defconfig    
        #make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv allwinner_d1_nezha_defconfig
        cp config/kernel_config linux/.config
    fi
    
    #make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv menuconfig
    make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv -j20 #zimage
    
    mkdir -p kernel_build
    cp linux/arch/riscv/boot/Image kernel_build
    cp linux/arch/riscv/boot/dts/allwinner/allwinner-d1-nezha-kit.dtb kernel_build
    cp linux/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb kernel_build
    #cp Fedora/boot/aw_nezha_d1_2G.dtb kernel_build
    #cp Fedora/boot/vmlinux-5.4.61+ kernel_build
    #cp Fedora/boot/vmlinuz-5.10.6-200.0.riscv64.fc33.riscv64 kernel_build
    
    cp config/kernel.its kernel_build
    
    make -C linux CROSS_COMPILE=riscv64-linux-gnu- ARCH=riscv INSTALL_PATH=../kernel_build zinstall
    
    #pushd kernel_build
    #mkimage -f kernel.its kernel.itb
    #popd
    
    
    dev=$(losetup -f)
    
    sudo losetup $dev sd.img
    sudo partprobe  $dev
    sudo mount $dev"p2" /mnt/image
    sudo cp kernel_build/vmlinuz-5.14.0-771261-g9d7ae926527f /mnt/image/vmlinuz
    sudo cp kernel_build/sun20i-d1-nezha.dtb /mnt/image/
    sudo cp config/grub.cfg /mnt/image/
    #sudo cp kernel_build/kernel.itb /mnt/image
    #sudo cp config/uEnv.txt /mnt/image 
    ls /mnt/image
    df -h /mnt/image
    sudo umount /mnt/image
    sudo losetup -d $dev
    
    #linux  (hd0,msdos2)/vmlinuz earlyprintk=sunxi-uart,0x02500000 console=ttyS0,115200 console=tty0 loglevel=8
    #devicetree (hd0,msdos2)/sun20i-d1-nezha.dtb
    
}

prepare
init_sd_card
spl
opensbi
u_boot
grub
kernel_build

