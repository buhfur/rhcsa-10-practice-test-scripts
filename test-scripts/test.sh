#!/bin/bash



cleanup_create_users () { 
    USERS=(edwin santos serene alex student)

    for x in ${USERS[@]}; do 
        echo $x
    done

}


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

    #return 0
}

create_groups

