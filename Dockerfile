FROM debian:buster-slim

RUN apt-get update && \
    apt-get install -y wget gnupg && \
    wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add - && \
    apt-get purge -y wget gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb http://build.openvpn.net/debian/openvpn/release/2.4 buster main" > /etc/apt/sources.list.d/openvpn.list

RUN apt-get update && \
    apt-get install -y bash iptables openvpn && \
    update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y curl unzip && \
    curl -sS 'https://www.privateinternetaccess.com/openvpn/openvpn.zip' -o /tmp/openvpn.zip && \
    unzip /tmp/openvpn.zip -d /openvpn && \
    rm /tmp/openvpn.zip && \
    apt-get purge -y curl unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ADD run.sh /openvpn/run.sh
RUN chmod +x /openvpn/run.sh

WORKDIR /openvpn

ENTRYPOINT ["/openvpn/run.sh"]
