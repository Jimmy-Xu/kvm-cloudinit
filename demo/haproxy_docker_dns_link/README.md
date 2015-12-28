**How to followup a container IP change when restarting a container?**
This demo aims at giving a solution to this question.

HAProxy 1.6 DNS resolution (http://blog.haproxy.com/2015/10/14/whats-new-in-haproxy-1-6/)
1. start app container
2. start haproxy container: link to app container
3. restart app container -> ip changed
4. haproxy container: inotifytools found /etc/hosts changed, then reload dnsmasq

	haproxy use dnsmasq as namserver
	dnsmasq use /etc/hosts as its database

>**dnsmasq**: tiny software which can act as a DNS server which takes /etc/hosts file as its database
>**inotifytools**: watch changes on /etc/hosts file and force dnsmasq to reload it when necessary


###########################################################################
# build docker image

	$ docker build -t demo1:haproxy_dns ./blog_haproxy_dns/
	$ docker build -t demo1:rsyslogd ./blog_rsyslogd/


###########################################################################
# start container

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

	curl http://[host_ip]:8000
	curl http://[host_ip]:8088


###########################################################################
# test ip change of appsrv1

	ip of appsrv1 changed from 172.17.0.3 to 172.17.0.4

### 1. start a new container appsrv2

	$ docker run --detach --name appsrv2 --hostname=appsrv2 nginx:latest


### 2. view current ip of appsrv1 appsrv2

	$ docker inspect --format "{{.NetworkSettings.IPAddress}}" appsrv1 appsrv2
	172.17.0.3
	172.17.0.4

	$ docker exec -it haproxy cat /etc/hosts | grep appsrv1
	172.17.0.3	appsrv1


### 3. change ip of appsrv1

	$ docker stop appsrv1 appsrv2
	$ docker start appsrv2 # => start appsrv2 first
	$ docker start appsrv1


### 4. check current ip again

	$ docker inspect --format "{{.NetworkSettings.IPAddress}}" appsrv1 appsrv2
	172.17.0.4 # => ip of appsrv1 changed from 172.17.0.3 => 172.17.0.4
	172.17.0.3


### 5. monitor haproxy events log

	$ docker exec -it rsyslogd tail -f /var/log/haproxy/events
	Dec 28 05:08:29 172.17.0.1 haproxy[11]: b_myapp/appsrv1 changed its IP from 172.17.0.3 to 172.17.0.4 by docker/dnsmasq.
	Dec 28 05:08:29 172.17.0.1 haproxy[11]: b_myapp/appsrv1 changed its IP from 172.17.0.3 to 172.17.0.4 by docker/dnsmasq.

	$ docker exec -it haproxy cat /etc/hosts | grep appsrv1
	172.17.0.4	appsrv1

### 6.test

	curl http://[host_ip]:8000
	curl http://[host_ip]:8088


###########################################################################
# Ref

### blog
http://blog.haproxy.com/2015/11/17/haproxy-and-container-ip-changes-in-docker/

### git repo
https://github.com/haproxytech/haproxy.git
