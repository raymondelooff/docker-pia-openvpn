FROM alpine:3.8

WORKDIR /root

RUN apk add --no-cache iptables openvpn

RUN apk add --no-cache --virtual .build-deps \
    curl \
    unzip && \
    curl -sS 'https://www.privateinternetaccess.com/openvpn/openvpn.zip' -o /tmp/openvpn.zip && \
    unzip /tmp/openvpn.zip -d /root && \
    rm /tmp/openvpn.zip && \
    apk del .build-deps

ADD run.sh /root/run.sh
RUN chmod +x /root/run.sh

ENV REGION 'Netherlands'

ENTRYPOINT ["/root/run.sh"]
