#blog
http://blog.haproxy.com/2015/11/17/haproxy-and-container-ip-changes-in-docker/

#git repo
https://github.com/haproxytech/haproxy.git

#build docker image
docker build -t demo1:haproxy_dns ./blog_haproxy_dns/
docker build -t demo1:rsyslogd ./blog_rsyslogd/


#start container

### 1.start rsyslogd container
docker run --detach --name rsyslogd --hostname=rsyslogd \
    --publish=172.17.0.1:8514:8514/udp \
    demo1:rsyslogd

### 2.start appsrv1 container
docker run --detach --name appsrv1 --hostname=appsrv1 nginx:latest

### 3.start haproxy container
docker run --detach --name haproxy --hostname=haproxy \
    --link appsrv1:appsrv1 \
    -p 8000:80 -p 8088:88 \
    demo1:haproxy_dns

### test
curl http://<ip>:8000
curl http://<ip>:8088
