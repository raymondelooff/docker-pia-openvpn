FROM alpine:3.9

RUN apk add --no-cache bash iptables openvpn

RUN apk add --no-cache --virtual .build-deps curl unzip && \
    curl -sS 'https://www.privateinternetaccess.com/openvpn/openvpn.zip' -o /tmp/openvpn.zip && \
    unzip /tmp/openvpn.zip -d /openvpn && \
    rm /tmp/openvpn.zip && \
    apk del .build-deps

ADD run.sh /openvpn/run.sh
RUN chmod +x /openvpn/run.sh

WORKDIR /openvpn

ENTRYPOINT ["/openvpn/run.sh"]
