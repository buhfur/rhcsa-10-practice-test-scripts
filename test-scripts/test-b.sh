#!/bin/bash 

# Script to complete entire RHCSA practice test in one bash script  


# ==============
#     Test
#     Functions
# ==============


test_func () {
    create_repo 
    install_packages
    mount_iso 
    return 0 
   
}

cleanup () { 
    cleanup_create_repo
    cleanup_install_packages
    cleanup_mount_iso
    cleanup_fstab
}

# ==============
#     Cleanup
#     Functions
# ==============

cleanup_create_repo () { 
    if [ -f /etc/yum.repos.d/local.repo ]; then 
         rm -rf /etc/yum.repos.d/local.repo && echo -e "\tRemoved repo file\n"
    fi
    return 0 
}

cleanup_install_packages () { 
    dnf history rollback 1 -y 
    return 0 
}

cleanup_fstab () {

    if [[ -f /etc/fstab.bak ]]; then
        yes | cp -f /etc/fstab.bak /etc/fstab # restore fstab backup 
        echo -e "Fstab backup restored.\n"
    else
        sed -i -e "/repo/d;/mydata/d" /etc/fstab # remove entry from fstab from create_mount_iso & create_lvm  
        return 0 
    fi


}

cleanup_create_disk () { # Removes ALL data from disk , unlike cleanup_resize_root_lvm which only removes the one 
    if [[ -f /mydata ]]; then 
        umount /mydata
    fi 

    wipefs -a /dev/sdb 
}


cleanup_mount_iso () { 

    if [[ -d /repo ]]; then 
        umount /repo
    fi
}




# ==============
#     Tasks
# ==============

install_packages() {
    dnf install -y policycoreutils-python-utils vsftpd nfs-utils vim autofs bash-completion dosfstools && echo -e "\tAll packages installed successfully\n"

    # Enable vsftpd daemon to be automatically started at reboot 
    systemctl enable vsftpd 

    return 0 
}

create_repo () {

    REPO_FILE="/etc/yum.repos.d/local.repo" 
    FILE_DATA="""[baseos]\nname=baseos\nbaseurl=http://192.168.1.180/repos/BaseOS\ngpgcheck=0\n[appstream]\nname=appstream\nbaseurl=http://192.168.1.180/repos/AppStream\ngpgcheck=0\n
    """

    echo -e $FILE_DATA >> $REPO_FILE && echo -e "\tAdded repo file\n"

    return 0 
}

mount_iso () {

    UUID=$(blkid /dev/sr0 -o value -s UUID)
    # Mount /dev/sr0 on /repo and add entry in fstab 
    if [[ ! -d /repo ]]; then 
        mkdir /repo && echo -e "\tCreating /repo\n"
    fi

    if [ ! -f /etc/fstab.bak ]; then
        yes | cp /etc/fstab /etc/fstab.bak 
    fi

    echo "UUID=$UUID /repo iso9660 defaults 0 0" >> /etc/fstab && echo -e "\tWrote /dev/sr0 entry to fstab\n"  
    systemctl daemon-reload && mount -a && return 0 
}


# WARNING: Cleanup for this function is not feasible if using xfs filesystem 
resize_root_lvm () { 
   
    # Create partition on /dev/sdb as lvm and add to almalinux vg 

    parted -s /dev/sdb mklabel gpt mkpart primary 1Mib 2Gib set 1 lvm on 
    vgextend almalinux /dev/sdb1 
    lvextend /dev/almalinux/root -L +1Gib 
    xfs_growfs / && echo -e "\tRoot Filesystem increased\n"
}

# ==============
#     END Tasks
# ==============


case $1 in 
    "cleanup")
        cleanup
        ;;
    "test")
        test_func
        ;;
    "all")
        test_func && cleanup
        ;;
    *)
        $1 # Runs any function if passed 
        ;;

esac
