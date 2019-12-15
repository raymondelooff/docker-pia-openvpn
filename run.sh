#!/bin/bash

set -euo pipefail

REGION="${REGION:=}"
ARGS="${ARGS:=}"

tun_device_setup() {
    if [[ ! -d /dev/net ]]; then
        mkdir /dev/net
    fi

    if [[ ! -c /dev/net/tun ]]; then
        echo 'TUN/TAP device does not exist. Trying to create it...'
        mknod /dev/net/tun c 10 200
        chmod 0666 /dev/net/tun

        if [[ -c /dev/net/tun ]]; then
            echo 'Created TUN/TAP device!'
        else
            echo 'TUN/TAP could not be created. Exiting.'
            exit 1
        fi
    fi
}

iptables_setup() {
    echo 'Setting up iptables...'

    # Allow OpenVPN traffic
    OPENVPN_FILE=
    CONFIG_FILE_REGEX='--config( |=)"?((.+).(ovpn|conf))"?'

    if [[ $ARGS =~ $CONFIG_FILE_REGEX ]]; then
        if [[ -a ${BASH_REMATCH[2]} ]]; then
            OPENVPN_FILE="${BASH_REMATCH[2]}"
        else
            echo 'Config file not found.'
        fi
    fi

    if [[ ! -z $OPENVPN_FILE ]]; then
        OPENVPN_PROTO=$(awk '/proto/ && $2 ~ /^[a-z]+$/ { print $2 }' "$OPENVPN_FILE")
        OPENVPN_PORTS=$(awk '/remote/ && $3 ~ /^[0-9]+$/ { print $3 }' "$OPENVPN_FILE")

        if [[ -n $OPENVPN_PROTO && -n $OPENVPN_PORTS ]]; then
            for OPENVPN_PORT in $OPENVPN_PORTS
            do
                echo "Allowing OpenVPN on ${OPENVPN_PORT}/${OPENVPN_PROTO}"
                iptables -A INPUT -p ${OPENVPN_PROTO} --sport ${OPENVPN_PORT} -m state --state ESTABLISHED,RELATED -j ACCEPT
                iptables -A OUTPUT -p ${OPENVPN_PROTO} --dport ${OPENVPN_PORT} -j ACCEPT
            done
        else
            echo 'Allowing OpenVPN on default 1194/udp'
            iptables -A INPUT -p udp --sport 1194 -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
        fi
    else
        echo 'Allowing OpenVPN on default 1194/udp'
        iptables -A INPUT -p udp --sport 1194 -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
    fi

    # Allow traffic to DNS servers
    iptables -A INPUT -p tcp --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT

    # Allow traffic on loopback interface
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Restrict incoming traffic from tunnel interfaces
    iptables -A INPUT -i tun+ -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i tun+ -j ACCEPT
    iptables -A OUTPUT -o tun+ -j ACCEPT

    # Allow traffic between other containers
    DOCKER_NETWORKS=$(ip route | awk '$3 ~ /eth/ { print $1 }')
    for DOCKER_NETWORK in $DOCKER_NETWORKS
    do
        iptables -A INPUT -s $DOCKER_NETWORK -j ACCEPT
        iptables -A OUTPUT -d $DOCKER_NETWORK -j ACCEPT
    done

    iptables -A INPUT -j REJECT --reject-with icmp-port-unreachable 2> /dev/null || iptables -A INPUT -j DROP
    iptables -A FORWARD -j REJECT --reject-with icmp-port-unreachable 2> /dev/null || iptables -A FORWARD -j DROP
    iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable 2> /dev/null || iptables -A OUTPUT -j DROP
}

openvpn_connect() {
    /bin/sh -c "openvpn $ARGS"
}

if [[ -n $REGION && ! -z $REGION ]]; then
    ARGS="${ARGS} --config \"${REGION}.ovpn\""
else
    echo 'Region not specified. PIA OpenVPN config file will not be loaded,'
    echo 'you may specify a region or add configuration manually.'
fi

for ARG in $@; do
    ARGS="${ARGS} ${ARG}"
done

tun_device_setup
iptables_setup
openvpn_connect
