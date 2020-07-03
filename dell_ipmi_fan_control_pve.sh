#!/bin/bash

DATE=$(date "+%Y-%m-%d %H:%M.%S")
echo "$DATE"

PID_FILE="/run/dell_ipmi_fan_control.pid"
IDRACIP="ip地址"  #iDRAC ip地址
IDRACUSER="用户名"  #iDRAC 用户名
IDRACPASSWORD="密码"  #iDRAC 密码
FAN1T="50"  #1档风扇启用温度
FAN2T="55"  #2档风扇启用温度
FAN3T="60"  #3档风扇启用温度
FAN0S="3"  #0档风扇速度设置 温度低于1档时启动
FAN1S="6"  #1档风扇速度设置
FAN2S="10"  #2档风扇速度设置
FAN3S="20"  #3档风扇速度设置
TEMPTHRESHOLD="65"  #自动风扇控制启用温度


DIR=$(cd "$(dirname "$0")";pwd)
FILENAME=$(echo $0 | awk -F "/" '{print $NF}')
 
if [ -f /etc/os-release ]; then
    source /etc/os-release
    if [ "$ID" == "centos" ]; then
        grep $FILENAME /var/spool/cron/root
        if [ "$?" != "0" ]; then
            echo "*/1 * * * * /bin/bash $DIR"/"$FILENAME >> /tmp/dell_ipmi_fan_control.log" >> /var/spool/cron/root
        fi
    elif [ "$ID" == "ubuntu" ]; then
        grep $FILENAME /var/spool/cron/crontabs/root
        if [ "$?" != "0" ]; then
            echo "*/1 * * * * /bin/bash $DIR"/"$FILENAME >> /tmp/dell_ipmi_fan_control.log" >> /var/spool/cron/crontabs/root
        fi
    elif [ "$ID" == "debian" ]; then
        grep $FILENAME /var/spool/cron/crontabs/root
        if [ "$?" != "0" ]; then
            echo "*/1 * * * * /bin/bash $DIR"/"$FILENAME >> /tmp/dell_ipmi_fan_control.log" >> /var/spool/cron/crontabs/root
        fi
    fi
else
    echo "System version too low or System mismatch"
    exit
fi

if [ "$ID" == "centos" ]; then
    if [ "$VERSION_ID" -ge "7" ]; then
        HAS_SYSTEMD=true
    fi
elif [ "$ID" == "ubuntu" ]; then
    if [ $(echo "$VERSION_ID >= "16.04"" | bc) -eq 1 ]; then
        HAS_SYSTEMD=true
    fi
elif [ "$ID" == "debian" ]; then
    if [ "$VERSION_ID" -ge "10" ]; then
        HAS_SYSTEMD=true
    fi
fi

echo
if [ "$HAS_SYSTEMD" == true ]; then
    SERVICE_PATH="/etc/systemd/system/dell_ipmi_fan_control.service"

    if [ ! -f $SERVICE_PATH ]; then
        FIRST_RUN=true
        cat>$SERVICE_PATH<<EOF
[Unit]
Description= dell fan control with ipmi
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/run/dell_ipmi_fan_control.pid
ExecStart=$DIR"/"$FILENAME

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start dell_ipmi_fan_control.service
    systemctl enable dell_ipmi_fan_control.service

    fi
fi


if [ "$FIRST_RUN" == true ]; then
    exit
fi

if [ -s $PID_FILE ]; then
    PID=$(cat $PID_FILE)
    echo "Service start，pid=$PID，exit"
    exit
else
    echo $$ > $PID_FILE
fi

while true; do
    T=$(ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD sdr type temperature | grep -E "^Temp" | cut -d"|" -f5 | cut -d" " -f2 | grep -v "Disabled")
	F0S=$(printf "0x%02x\n" $FAN0S)
	F1S=$(printf "0x%02x\n" $FAN1S)
	F2S=$(printf "0x%02x\n" $FAN2S)
	F3S=$(printf "0x%02x\n" $FAN3S)

    if [[ $T =~ ^\d* ]]; then
        echo "$IDRACIP: -- CPU Temp $T --"

        if [[ $T > $TEMPTHRESHOLD ]]; then
            echo "-- CPU Temp > $TEMPTHRESHOLD, Start auto fan control --"
			ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0xce 0x00 0x16 0x05 0x00 0x00 0x00 0x05 0x00 0x01 0x00 0x00
            ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x01
        else
            echo "-- CPU Temp < $TEMPTHRESHOLD, Start Manual fan control --"
			ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0xce 0x00 0x16 0x05 0x00 0x00 0x00 0x05 0x00 0x01 0x00 0x00
            ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x01 0x00
 
            if [[ $T > $FAN3T ]]; then
                echo "-- CPU Temp > $FAN3T,Set fan speed $FAN3S% --"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff $F3S
            elif [[ $T > $FAN2T ]] && [[ $T < $FAN3T ]]; then
                echo "-- CPU Temp > $FAN2T,Set fan speed $FAN2S% --"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff $F2S
            elif [[ $T > $FAN1T ]] && [[ $T < $FAN2T ]]; then
                echo "-- CPU Temp > $FAN1T,Set fan speed $FAN1S% --"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff $F1S
            else
                echo "-- CPU Temp < $FAN1T,Set fan speed $FAN0S% --"
                ipmitool -I lanplus -H $IDRACIP -U $IDRACUSER -P $IDRACPASSWORD raw 0x30 0x30 0x02 0xff $F0S
            fi 
        fi 
    else
        continue
    fi 
done
