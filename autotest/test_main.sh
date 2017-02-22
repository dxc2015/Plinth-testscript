#!/bin/bash



# main
option=`echo $1 | tr '[A-Z]' '[a-z]'`

case "$option" in
    sas)
        source ./sas_autotest/sas_mian.sh
    ;;
    hns)
        source ./sas_autotest/hns_mian.sh
    ;; 
    pcie)
        source ./sas_autotest/pcie_mian.sh
    ;;
    *)
        echo "test_main.sh [options]"
        echo "sas     SAS module test."
        echo "hns     HNS module test."
        echo "pcie    PCIE module test."
    ;;
esac
