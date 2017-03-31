#!/bin/bash

###########################################
# the main entry, use to run all test work.
###########################################


# Load configuration file
. config/common_lib

# Update boot Image file
# IN : N/A
# OUT: N/A
function update_image()
{
    [ ! -e ${IMAGE_FILE} ] && echo "${IMAGE_FILE} file does not exist, do not update the Image file" && return 1
    cp ${IMAGE_FILE} ${IMAGE_DIR_PATH}
    [ $? != 0 ] && echo "Update Image failed." && return 1
}

# connect the board and run test script
# IN : $1 board no
#      $2 test run script
# OUT: N/A
function board_run_back()
{
    cp ~/grub-back.cfg ~/grub.cfg
    board_reboot $1
    [ $? != 0 ] && echo "board reboot failed." && return 1
    expect -c '
    set timeout -1
    set boardno '$1'
    set user '$SYSTEM_USER'
    set passwd '$SYSTEM_PASSWD'
    set server_user '$SERVER_USER'
    set server_passwd '$SERVER_PASSWD'
    set test_run_script '$2'
    set SERVER_IP '$SERVER_IP'
    set autotest_zip '${AUTOTEST_ZIP_FILE}'
    set report_path '${REPORT_PATH}'
    set report_file '${REPORT_FILE}'
    set mode_report_file '$3'
    spawn board_connect ${boardno}
    send "\r"
    expect -re {Press any other key in [0-9]+ seconds to stop automatical booting}
    send "\r"
    send "\r"
    expect "login:"
    send "${user}\r"
    expect "Password:"
    send "${passwd}\r"
    sleep 5
    expect -re ":.*#"

    send "echo `ifconfig eth0|grep -Po \"(?<=(inet addr:))(.*)(?=(Bcast))\"` >backIP.txt\r"
    expect ".*#"
    # cp test script to server
    send "rm -f ~/.ssh/known_hosts\r"
    send "rm -f ~/.ssh/authorized_keys\r"
    send "scp backIP.txt ${server_user}@${SERVER_IP}:~/autotest\r"
    expect "Are you sure you want to continue connecting (yes/no)?"
    send "yes\r"
    expect "password:"
    send "${server_passwd}\r"		
    expect -re ":.*#"
    '

    export BACK_IP=`cat backIP.txt|sed s/[[:space:]]//g`
    cfg_file=./xge_autotest/config/xge_test_config
    sed -i '/^BACK_IP.*/d' $cfg_file && echo BACK_IP="$BACK_IP" >>$cfg_file
    cd ~/
    tar -zcvf  ${AUTOTEST_ZIP_FILE} autotest
    [ $? != 0 ] && echo "tar test script failed." && return 1
    cp ~/grub-host.cfg ~/grub.cfg
    return 0
}

# connect the board and run test script
# IN : $1 board no
#      $2 test run script
# OUT: N/A
function board_run()
{
    board_reboot $1
    [ $? != 0 ] && echo "board reboot failed." && return 1
	
    expect -c '
    set timeout -1
    set boardno '$1'
    set user '$SYSTEM_USER'
    set passwd '$SYSTEM_PASSWD'
    set server_user '$SERVER_USER'
    set server_passwd '$SERVER_PASSWD'
    set test_run_script '$2'
    set SERVER_IP '$SERVER_IP'
    set autotest_zip '${AUTOTEST_ZIP_FILE}'
    set report_path '${REPORT_PATH}'
    set report_file '${REPORT_FILE}'
    set mode_report_file '$3'
    spawn board_connect ${boardno}
    send "\r"
    expect -re {Press any other key in [0-9]+ seconds to stop automatical booting}
    send "\r"
    send "\r"
    expect "login:"
    send "${user}\r"
    expect "Password:"
    send "${passwd}\r"
    sleep 8
    expect -re ":.*#"
    # cp test script from server
    send "rm -f ~/.ssh/known_hosts\r"
    send "scp ${server_user}@${SERVER_IP}:~/${autotest_zip} ~/\r"
    expect "Are you sure you want to continue connecting (yes/no)?"
    send "yes\r"
		
    expect "password:"
    send "${server_passwd}\r"
		
    expect ".*#"
    send "tar -zxvf ${autotest_zip}\r"
    expect ".*#"
    send "cd ~/autotest;bash -x ${test_run_script}\r"
    expect -re ":.*#"
    send "rm -f ~/.ssh/known_hosts\r"
    send "scp ${report_file} ${server_user}@${SERVER_IP}:${report_path}/${mode_report_file}\r"
    expect "Are you sure you want to continue connecting (yes/no)?"
    send "yes\r"

    expect "password:"
    send "${server_passwd}\r"
    expect -re ":.*#"
    send "cd ~;rm -rf ~/autotest;rm -rf ${autotest_zip}\r"
    expect -re ":.*#"
    '
}

# Main operation function
# IN : N/A
# OUT: N/A
function main()
{
    TOP_DIR=$(cd "`dirname $0`" ; pwd)	
    #update image
    #update_image
    killall ipmitool >/dev/null

    cd ~/
    tar -zcvf  ${AUTOTEST_ZIP_FILE} $TOP_DIR
    [ $? != 0 ] && echo "tar test script failed." && return 1

    #Output log file header
    #echo "Module Name,JIRA ID,Test Item,Test Case Title,Test Result,Remark" > ${REPORT_FILE}

    #SAS Module Main function call
    [ ${RUN_SAS} -eq 1 ] && board_run ${SAS_BORADNO} ${SAS_MAIN} ${SAS_REPORT_FILE} &
    #PXE Module Main function call
    [ ${RUN_XGE} -eq 1 ] &&  board_run_back ${BACK_XGE_BORADNO} ${XGE_MAIN} ${XGE_REPORT_FILE}  && board_run ${XGE_BORADNO} ${XGE_MAIN} ${XGE_REPORT_FILE} &
    #PCIE Module Main function call
    [ ${RUN_PCIE} -eq 1 ] && board_run ${PCIE_BORADNO} ${PCIE_MAIN} ${PCIE_REPORT_FILE} &	

    # Wait for all background processes to end
    wait
}

main

# clean exit so lava-test can trust the results
exit 0

