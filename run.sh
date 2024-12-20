#!/bin/bash

usage() {
    echo "Usage: $0 [options...]
    flags:
        -f | --force
            force gpu to run at a static Clock
    options:
        -c | --charge-limit <int val>
            set max battery charge limit
        -l | --gpu-lower <int val>
            set lower gpu clock limit
        -u | --gpu-upper <int val>
            set upper gpu clock limit
    "
}

error_message() {
    echo "Error: $1" 1>&2
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
            echo "Charge limit is set to $2%."
            charge_limit=$2
            shift 2
            ;;
        -l | --gpu-lower)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error_message "-l | --gpu-lower requires an integer argument"
            fi
            echo "Lower GPU clock is set to $2 MHz"
            gpu_lower=$2
            shift 2
            ;;
        -u | --gpu-upper)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error_message "-u | --gpu-upper requires an integer argument"
            fi
            echo "Upper GPU clock is set to $2 MHz"
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

echo "All Set."
exit 0;
