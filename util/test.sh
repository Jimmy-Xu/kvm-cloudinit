echo "======= run in vm ========"
if [ -f /tmp/run.log ];then
	cat /tmp/run.log
fi
echo "test.sh:$(date +'%F %T')"
echo "-----------------------------"
echo hello world
#echo "127.0.0.1 $(hostname)" >> /etc/hosts
cat /etc/hosts
echo "=========================="
