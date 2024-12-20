#!/bin/bash

usage() {
    echo -e "Usage: $0 [options...]\n
    flags:
        \e[1m-f | --force\e[0m
            force gpu to run at a static Clock
    options:
        \e[1m-c | --charge-limit <int val>\e[0m
            set max battery charge limit
        \e[1m-l | --gpu-lower <int val>\e[0m
            set lower gpu clock limit
        \e[1m-u | --gpu-upper <int val>\e[0m
            set upper gpu clock limit
    "
}

error_message() {
    echo -e "\e[31mError:\e[0m \e[1m$1\e[0m" 1>&2
    usage
    exit 1
}

charge_limit=100
gpu_lower=
gpu_upper=
force=false
gpu_set="-lgc"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c | --charge-limit)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error_message "-c | --charge-limit requires an integer argument"
            fi
            echo -e "\e[32mCharge limit is set to $2%.\e[0m"
            charge_limit=$2
            shift 2
            ;;
        -l | --gpu-lower)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error_message "-l | --gpu-lower requires an integer argument"
            fi
            echo -e "\e[32mLower GPU clock is set to $2 MHz\e[0m"
            gpu_lower=$2
            shift 2
            ;;
        -u | --gpu-upper)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error_message "-u | --gpu-upper requires an integer argument"
            fi
            echo -e "\e[32mUpper GPU clock is set to $2 MHz\e[0m"
            gpu_upper=$2
            shift 2
            ;;
        -f | --force)
            force=true
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            error_message "Invalid option: $1"
            ;;
    esac
done

# Check if both upper and lower GPU clock values are provided unless force is set 

if [[ -z "$gpu_lower" && -z "$gpu_upper" ]]; then
    gpu_set="-rgc"
    gpu_clock=
elif [[ "$force" == true ]]; then
    if [[ -z "$gpu_upper" ]]; then
        error_message "Force is set, but upper GPU clock value is not provided"
    fi
    gpu_clock=$gpu_upper
else
    if [[ -z "$gpu_lower" || -z "$gpu_upper" ]]; then
        if [[ -n "$gpu_upper" ]]; then
            gpu_lower=0
        else
            error_message "Both lower and upper GPU clock values must be provided. $([[ -n "$gpu_upper" ]] && echo 'Or set force flag along with gpu-upper')"
        fi
    fi
    gpu_clock="$gpu_lower,$gpu_upper"
fi

echo -e '\n'

SCRIPT_CHARGE="/usr/bin/charge_limit"
SCRIPT_GPU="/usr/bin/gpu_clock"
#? set charge limit and gpu clock scripts in place
./set.charge_limit "$charge_limit" | sudo tee "$SCRIPT_CHARGE" > /dev/null
./set.gpu_clock "$gpu_set" "$gpu_clock" | sudo tee "$SCRIPT_GPU" > /dev/null
sudo chmod +x $SCRIPT_GPU $SCRIPT_CHARGE
$SCRIPT_CHARGE;
$SCRIPT_GPU


#? set startup service and enable it
SERVICES_LOCATION="/etc/systemd/system/"
SERVICES_NAME="system_startup.service"
./set.service.system_startup "$SCRIPT_CHARGE & $SCRIPT_GPU" | sudo tee "$SERVICES_LOCATION$SERVICES_NAME" > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable $SERVICES_NAME
sudo systemctl start $SERVICES_NAME
#? startup scripts done


#? set charge_limit when waking from sleep
CHARGE_LIMIT_WAKEUP="/usr/lib/systemd/system-sleep/charge_limit_wake"
./set.charge_limit_wake $SCRIPT_CHARGE | sudo tee $CHARGE_LIMIT_WAKEUP > /dev/null
sudo chmod +x $CHARGE_LIMIT_WAKEUP

#? set charge limit when switching power source modes
POWER_SWITCHING_RULES="/etc/udev/rules.d/99-power.rules"
./set.charge_limit_rules $SCRIPT_CHARGE | sudo tee $POWER_SWITCHING_RULES > /dev/null
sudo udevadm control --reload-rules

echo -e "\e[32mAll Set.\e[0m"
exit 0;
