#blog
http://blog.haproxy.com/2015/11/17/haproxy-and-container-ip-changes-in-docker/

#git repo
https://github.com/haproxytech/haproxy.git

#build docker image
docker build -t blog:haproxy_dns ./blog_haproxy_dns/
docker build -t blog:rsyslogd ./blog_rsyslogd/
