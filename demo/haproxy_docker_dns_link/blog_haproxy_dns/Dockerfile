FROM haproxy:1.6
MAINTAINER Jimmy Xu <xjimmyshcn@gmail.com>

ADD sources.list /etc/apt/sources.list

# install third party tools
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install --yes inotify-tools dnsmasq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# traffic ports
EXPOSE 80 443

# administrative ports
# 82: TCP stats socket
# 88: HTTP stats page
EXPOSE 81 82 88

ADD haproxy.cfg /etc/haproxy/haproxy.cfg
ADD haproxy.sh /

ENTRYPOINT /haproxy.sh

