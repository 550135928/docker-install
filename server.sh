#!/usr/bin/env bash

## The script used to start flow.ci server from docker-compose ##

printHelp() 
{
	echo ""
   	echo "Usage: $0 [OPTIONS] COMMAND"

	echo ""
	echo "Example: ./server.sh -h 172.20.2.1 -e admin@flow.ci -p yourpassword start"

	echo ""
	echo "Options:"
	echo -e " -h\t Host ip address"
   	echo -e " -e\t Default admin email"
   	echo -e " -p\t Default admin password"

	echo ""
	echo "Commands:"
	echo -e " start\t start ci server"
	echo -e " stop\t stop ci server"
	echo -e " down\t remove ci server containers"
	echo -e " help\t print help message"
	
   	exit 1 # Exit script after printing help
}

initEnv() 
{
	export FLOWCI_SERVER_HOST=$HOST
	export FLOWCI_RABBIT_HOST=$HOST
	export FLOWCI_ZOOKEEPER_HOST=$HOST

	export FLOWCI_SERVER_PORT=8080
	export FLOWCI_SERVER_URL="http://$FLOWCI_SERVER_HOST:$FLOWCI_SERVER_PORT"

	export FLOWCI_WEB_PORT=2015

	export FLOWCI_DEFAULT_ADMIN_EMAIL=$EMAIL
	export FLOWCI_DEFAULT_ADMIN_PASSWORD=$PASSWORD

	export FLOWCI_DEFAULT_MINIO_ACCESS_KEY=minio
	export FLOWCI_DEFAULT_MINIO_SECRET_KEY=minio123

	## set agnet volumes for local auto agent
	export FLOWCI_AGENT_VOLUMES="name=pyenv,dest=/ci/python,script=init.sh"
}

printInfo()
{
	echo ""
	echo "[INFO] Server URL:	$FLOWCI_SERVER_URL"
	echo "[INFO] Admin Email:	$FLOWCI_DEFAULT_ADMIN_EMAIL"
	echo "[INFO] Admin Password:	$FLOWCI_DEFAULT_ADMIN_PASSWORD"

	echo ""
	echo -e "\xF0\x9f\x8d\xba  HOW TO:"
	echo -e "\xF0\x9F\x91\x89   Open Web UI:\t http://$FLOWCI_SERVER_HOST:$FLOWCI_WEB_PORT"
	echo -e "\xF0\x9F\x91\x89   Start Agent:\t ./agent.sh -u $FLOWCI_SERVER_URL -t your_agent_token start"
	echo ""
}

setDefaultValue()
{
	if [[ ! -n $HOST ]]; then
		if [[ $OSTYPE == "darwin"* ]]; then
			HOST=$(ipconfig getifaddr en0)
			echo "[WARN]: Host ip not defined, using ip $HOST"
		
		elif [[ $OSTYPE == "linux"* ]]; then
			interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route| head -1)
			HOST=$(ip addr show ${interface} 2>/dev/null| grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
			echo "[WARN]: Host ip not defined, using ip $HOST"

		else 
			echo "[WARN]: Host ip addr cannot detected, please specify ip or host name by -h your_ip_or_host_name"
			exit 1
		fi
	fi

	if [[ ! -n $EMAIL ]]; then
		echo "[WARN]: Admin email not defined, using 'admin@flow.ci' as admin email"
		EMAIL="admin@flow.ci"
	fi

	if [[ ! -n $PASSWORD ]]; then
		echo "[WARN]: Admin password not defined, using 'example' as admin password"
		PASSWORD="example"
	fi
}

pullAgentImage()
{
	img=$(docker images flowci/agent:latest --format "{{.ID}}")
	if [[ ! -n $img ]]; then
		echo "[INFO] Pull agent docker image.."
		docker pull flowci/agent:latest
	fi
}

setPyenvForLocalAgent() 
{
	docker volume create pyenv
	docker run --rm -v pyenv:/ws flowci/pyenv:1.3 bash -c "/ws/init-pyenv-volume.sh"
}

while getopts ":h:e:p" arg; do
  case $arg in
    h) HOST=$OPTARG;;
    e) EMAIL=$OPTARG;;
    p) PASSWORD=$OPTARG;;
  esac
done

COMMAND="${@: -1}"

case $COMMAND in
	start)
		pullAgentImage
		setDefaultValue
		initEnv
		printInfo
		setPyenvForLocalAgent
		docker-compose -f server.yml up -d
		;;

	stop)
		initEnv
		docker-compose -f server.yml stop
		;;

	down)
		initEnv
		docker-compose -f server.yml down
		;;

	*)
		printHelp
		;;
esac
