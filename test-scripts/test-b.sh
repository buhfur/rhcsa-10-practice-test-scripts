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
    create_groups 
    create_users
    create_shared_group_files
    create_disk
    create_lvm
    copy_edwin_files
    create_scheduled_task
    create_nfs_directories
    create_autofs 
    return 0 
   
}

cleanup () { 
    cleanup_create_repo
    cleanup_install_packages
    cleanup_mount_iso
    cleanup_create_groups 
    cleanup_create_users
    cleanup_create_lvm
    cleanup_create_disk
    cleanup_shared_group_files
    cleanup_edwin_files
    cleanup_scheduled_task
    cleanup_create_nfs_directories
    cleanup_create_autofs
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

cleanup_create_disk () { 
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
