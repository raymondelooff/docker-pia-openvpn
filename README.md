# OpenVPN client for Docker

This image allows you to use an OpenVPN client that connects to Private Internet Access or every other OpenVPN server. The image contains default Private Internet Access configuration files, which allows you to connect to Private Internet Access by just setting the preferred region. The purpose of this image is just to set up a VPN connection. The network stack of this image can be used to route traffic from other containers through the OpenVPN tunnel.

The image contains a script that configures the TUN/TAP device and sets up a few `iptables` rules to restrict incoming and outgoing traffic. The firewall allows traffic to all Docker subnets/networks that are connected to the container. All DNS requests are also allowed by the firewall. Other outgoing traffic is forced through the VPN tunnel. All traffic will be blocked by the firewall if the OpenVPN connection fails.

## Usage

The image contains PIA config files to easily connect to OpenVPN servers from PIA. However, this image can also be used as a generic OpenVPN client. The firewall will adapt to the given configuration file, even when if it's a custom config file.

Important: You will need to specify custom DNS servers. The DNS servers listed below are servers from PIA. By using the PIA DNS servers you will get [DNS Leak Protection](https://www.privateinternetaccess.com/pages/client-support/#tenth). You may also use other public DNS resolvers. All DNS requests are allowed by the firewall, so DNS won't be routed through the OpenVPN tunnel.

```
docker network create proxy
```

### Using PIA config files

```
docker run -d \
    --name=openvpn-client \
    --cap-add=NET_ADMIN \
    --net proxy \
    --dns 209.222.18.222 \
    --dns 209.222.18.218 \
    -v /path/to/auth-user-pass.txt:/openvpn/auth-user-pass.txt \
    -e REGION='US West' \
    raymondelooff/pia-openvpn:latest --auth-user-pass auth-user-pass.txt
```

### Using custom config files

```
docker run -d \
    --name=openvpn-client \
    --cap-add=NET_ADMIN \
    --net proxy \
    --dns 1.1.1.1 \
    --dns 1.0.0.1 \
    -v /path/to/client.conf:/openvpn/client.conf \
    -v /path/to/auth-user-pass.txt:/openvpn/auth-user-pass.txt \
    raymondelooff/pia-openvpn:latest --config client.conf --auth-user-pass auth-user-pass.txt
```

## Using the VPN tunnel

Using the OpenVPN tunnel with other images is easy. Just specify the OpenVPN container name as the network for every container you would like to route through the tunnel.

```
docker run --net=container:openvpn-client ...
```

## Accessing ports of the containers

You can't bind to ports of containers that use the OpenVPN container network because of Docker limitations. You can only access the ports (e.g. web interfaces on port 80) by using a proxy container that is connected to the same network as the OpenVPN container. `haproxy` is a great and very lightweight application that allows you to do this. Configuring `haproxy` is also pretty easy. See the snippets below for an example. Check the `haproxy` documentation for more advanced configurations if needed.

`haproxy.cfg`

```
global
    maxconn 1024
    pidfile /var/run/haproxy.pid

defaults
    log     global
    mode    tcp
    timeout connect 5000
    timeout client  50000
    timeout server  50000

listen web
    bind :80
    server webserver-01 openvpn-client:80 check
```

```
docker run -d \
    --name=haproxy \
    --network=proxy \
    -v /path/to/etc/haproxy:/usr/local/etc/haproxy \
    -p 80:80 \
    haproxy:latest
```

## Compatibility with Synology DSM

This image can be used on Synology DSM systems that support Docker. However, Synology DSM doesn't insert the required TUN/TAP kernel module by default, unless you've configured an OpenVPN connection in the Network settings of Synology DSM. When you don't have an OpenVPN connection configured in DSM, you can insert the kernel module manually on boot. Configuring this is very easy and can be done without using the command line.

1. Go to Task Scheduler section in the Control Panel
2. Click Create, then 'Triggered Task' and then 'User-defined script'
3. Configure the task. Select 'root' as the user and 'Boot-up' as the event.
4. Click on 'Task Settings' and add the following script:

    ```
    #!/bin/sh

    if ( !(lsmod | grep -q "^tun\s") ); then
        insmod /lib/modules/tun.ko
    fi
    ```

    This script will check if the required TUN/TAP kernel module is loaded, and inserts the module if it isn't already inserted.

5. Save the task by clicking 'OK'.

## License & Copyright

Copyright (c) 2018 Raymon de Looff <raydelooff@gmail.com>.
This project is licensed under the GPLv3 license.
