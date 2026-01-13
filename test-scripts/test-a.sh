#!/bin/bash 

# Script to complete entire RHCSA practice test in one bash script  
# Each task is divided up into functions , with a correlating "cleanup" which reverts all changes made 

#set -euxo pipefail # Error handling 


# TODO: complete nfs mount function 


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

cleanup_scheduled_task () { 
    rm -rf /var/spool/cron/root && echo -e "\t/var/spool/cron/root has been removed\n"
}

cleanup_edwin_files () {
    rm -rf /rootedwinfiles
}

# TODO: TEST 
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

# Call before cleanup_disk 
cleanup_create_lvm () { 
    if [[ $(findmnt /mydata) != "" ]]; then 
        umount /mydata 
    fi
    yes | lvremove /dev/myvg/mydata && vgremove myvg && pvremove /dev/sdb1

}
cleanup_shared_group_files () { 
    ls -al /groups
    rm -rf /groups && echo -e "\tRemoved shared group dirs.\n"
    return 0  
}

cleanup_mount_iso () { 

    if [[ -d /repo ]]; then 
        umount /repo
    fi
}

cleanup_create_users () { 
    USERS=(linda anna edwin santos serene alex student bob)

    for x in ${USERS[@]}; do 
        userdel -Z -r $x 
        find / -user $x | xargs rm -rf # remove all users files in other filesystems 
    done

    # Restore login.defs backup 
    yes | cp /etc/login.defs.bak /etc/login.defs && echo -e "Restored login.defs backup\n"
    return 0 

}

cleanup_create_groups (){ 
    USER_GROUPS=(operations livingopensource)
    for x in ${USER_GROUPS[@]}; do 
        groupdel $x && echo -e "Group $x removed\n" 
    done
    return 0 
}
# ==============
#   END CLEANUP
# ==============





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

# TODO: TEST 
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

# Gets called by create_users 
create_groups () {
    USER_GROUPS=(operations livingopensource)
    for x in ${USER_GROUPS[@]}; do
        # Check if group exists 
        if [ $(getent group $x) ]; then
            echo -e "\tGroup $x already exists\n"
        else
            groupadd $x && echo -e "\tGroup $x has been added\n"
        fi
    done

    return 0
}

# Sets up all users and default values for the tst 
create_users () { 

    # set defaults for new users  
    useradd student && echo 'password' | passwd student --stdin && echo -e "User Student created\n"

    USERS=(linda anna edwin santos serene alex bob )

    # Set default password validity for 90 days & Set default UID to 2000 
    sed -i.bak -e "s/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/;/^UID_MAX/d; \$a\UID_MIN\t\t2000" /etc/login.defs && echo -e "\tChanged Password Validity to 90 days\n"

    for user in ${USERS[@]}; do 
        case $user in 
            "edwin"|"santos")
               useradd $user -G livingopensource 
               if [ $user == "santos" ]; then
                   usermod $user -u 1234 -s /usr/sbin/nologin
               fi
               ;;
            "serene"|"alex")
                useradd $user -G operations
               ;;
           *)
               useradd $user 
       esac
    done
    
}

# Called after create_users 
create_shared_group_files () { 
    mkdir -p /groups/{operations,livingopensource}


    for group_dir in /groups/*; do
        echo $group_dir
    done

    GROUP_NAMES=(operations livingopensource)
    for x in ${GROUP_NAMES[@]}; do 
        chown :$x /groups/$x
        chmod 2770 /groups/$x && echo -e "\tChanged Group perms on shared directories\n"
    done
}


create_disk () {
    DISK=/dev/sdb
    # Create partition and mark as LVM 
    parted -s "$DISK" mklabel gpt mkpart primary 1Mib 2Gib set 1 lvm on  
    partprobe "$DISK"

}
# Called after create_disk 
create_lvm () { 
    if [[ ! -d /mydata ]]; then
        mkdir /mydata 
    fi 
    yes | vgcreate myvg -s 8Mib /dev/sdb1 
    yes | lvcreate myvg -n mydata -L +500Mib 

    # setup fs on partition , add entry to fstab 
    if [ ! -f /etc/fstab.bak ]; then 
        yes | cp /etc/fstab /etc/fstab.bak
    fi 

    mkfs.ext4 /dev/myvg/mydata  
    UUID=$(blkid /dev/myvg/mydata -o value -s UUID)
    echo "UUID=$UUID /mydata ext4 defaults 0 0" >> /etc/fstab && echo -e "\tWrote /dev/myvg/mydata entry to fstab\n"  

    systemctl daemon-reload && mount -a 
}

copy_edwin_files () {

    if [ ! -f /rootedwinfiles ]; then
        mkdir /rootedwinfiles
    fi

    for x in $(find / -type f -user edwin 2> /dev/null); do 
        yes | cp -r $x /rootedwinfiles
    done
}

create_scheduled_task () {
    echo "0 2 * * 1-5 /bin/sh touch /etc/motd" > /var/spool/cron/root
    CRON_NEXT=$(date -d "@$(cronnext -i root | awk -F " " '{print $2}')")
    echo -e "\tNext Cronjob will run on $CRON_NEXT\n"
}

# TODO : create and test cleanup function  
cleanup_create_nfs_directories () {
    setsebool -P use_nfs_home_dirs off 

    if [ -d /users ]; then
        rm -rf /users && echo -e "\tRemoved /users directory\n"
    fi 
    firewall-cmd --reset-to-defaults && firewall-cmd --reload 

    rm -rf /etc/exports  # Remove /etc/exports file 

    # Stop nfs-server service 
    systemctl stop nfs-server && systemctl disable nfs-server && systemctl daemon-reload 

} 

create_nfs_directories () {

    # Enable nfs home directories 
    setsebool -P use_nfs_home_dirs on && echo -e "\tEnabled NFS home dirs in SELinux\n"

    USERS=(linda anna)
    # Create nfs directories 
    mkdir -p /users/{linda,anna} 
    # give users ownership over their directories 
    for user in ${USERS[@]}; do 
        chown $user:$user /users/$user 
    done

    # add directories to exports file 
    
    cat << EOF > /etc/exports
/users/linda    *(rw,no_root_squash)
/users/anna     *(rw,no_root_squash)
EOF
    # Add firewall rules 
    SERVICES=(rpc-bind mountd nfs)

    for service in ${SERVICES[@]}; do 
        firewall-cmd --add-service $service --permanent 
    done 
    firewall-cmd --reload 
    
    # Enable nfs-server 
    for x in {enable,start}; do 
        systemctl $x nfs-server --now
    done
    
}

cleanup_create_autofs () {
    # Remove entries from autofs config files 
    sed -i "/users/d" /etc/auto.master && echo -e "\tRemoved entry from /etc/auto.master\n"
    sed -i "/nobind/d" /etc/auto.home-users && echo -e "\tRemoved entry from /etc/auto.home-users\n"
    # disable autofs service 
    umount -l /home/users
    systemctl stop autofs && systemctl disable autofs && systemctl daemon-reload
}

create_autofs () { 
    # append auto.master file 
    cat << EOF >> /etc/auto.master 
/home/users /etc/auto.home-users
EOF
    
    # append /etc/auto.home-users file 
    cat << EOF >> /etc/auto.home-users 
* -fstype=nfs,rw,nobind localhost.localdomain:/users/&
EOF
    systemctl enable --now autofs && systemctl start --now autofs 

    # Set linda and annas home to the new nfs share 
    for user in {linda,anna}; do 
        usermod $user -d /home/users/$user && echo -e "\tSet $user home to /home/users/$user\n"
    done

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
