#!/bin/sh

set -euo pipefail

DOCKER_NETWORKS=$(ip route | awk '$3 ~ /eth/ { print $1 }')
ARGS=

tun_device_setup() {
    if [[ ! -d /dev/net ]]; then
        mkdir /dev/net
    fi

    if [[ ! -c /dev/net/tun ]]; then
        echo 'TUN/TAP device does not exist. Creating...'
        mknod /dev/net/tun c 10 200
        chmod 0666 /dev/net/tun

        if [[ -c /dev/net/tun ]]; then
            echo 'Created TUN/TAP device'
        else
            echo 'TUN/TAP could not be created. Exiting...'
            exit 1
        fi
    fi
}

openvpn_connect() {
    openvpn $ARGS
}

iptables_setup() {
    iptables -N INPUT 2> /dev/null
    iptables -N FORWARD 2> /dev/null
    iptables -N OUTPUT 2> /dev/null

    # Allow OpenVPN traffic
    OPENVPN_FILE=$(echo $ARGS | awk '/--config/ { print $2 }')
    if [[ -n $OPENVPN_FILE ]]; then
        OPENVPN_PROTO=$(awk '/proto/ && $2 ~ /^[a-z]{3}$/ { print $2 }' "$OPENVPN_FILE")
        OPENVPN_PORT=$(awk '/remote/ && $3 ~ /^[0-9]+$/ { print $3 }' "$OPENVPN_FILE")

        if [[ -n $OPENVPN_PROTO -a -n $OPENVPN_PORT ]]; then
            iptables -A INPUT -p ${OPENVPN_PROTO} --sport ${OPENVPN_PORT} -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -p ${OPENVPN_PROTO} --dport ${OPENVPN_PORT} -j ACCEPT
        else
            iptables -A INPUT -p udp --sport 1194 -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
        fi
    else
        iptables -A INPUT -p udp --sport 1194 -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
    fi

    # Generic rules
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -p icmp -j ACCEPT

    # Allow traffic to DNS servers
    iptables -A INPUT -p tcp --sport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -p udp --sport 53 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

    # Allow traffic on loopback interface
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Restrict incoming traffic from tunnel interfaces
    iptables -A INPUT -i tun+ -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -o tun+ -j ACCEPT

    # Allow traffic between other containers
    for DOCKER_NETWORK in $DOCKER_NETWORKS
    do
        iptables -A INPUT -s $DOCKER_NETWORK -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -d $DOCKER_NETWORK -j ACCEPT
    done

    iptables -A INPUT -j REJECT --reject-with icmp-port-unreachable
    iptables -A FORWARD -j REJECT --reject-with icmp-port-unreachable
    iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable
}

if [[ -n $REGION ]]; then
    ARGS="${ARGS} --config ${REGION}.ovpn"
else
    echo 'Region not specified. Default PIA OpenVPN config will not be loaded.'
fi

for ARG in $@; do
    ARGS="${ARGS} \"$ARG\""
done

tun_device_setup
iptables_setup
openvpn_connect
