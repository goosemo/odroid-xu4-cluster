#!/usr/bin/env bash

# remote_command_exec
#	Executes a command remotely
#
#	Arguments
#		$1 - the server address to connect to
#		$2 - The user to execute the command as
#		$3 - the command to execute
#
function remote_command_eval () 
{
	if [ "$START_QFS_SH_DEBUG" = true ]; then
		echo "Running: ssh -l ${2} ${1} \"${3}\""
	fi
	local RESULTS
    RESULTS=$(ssh -l ${2} ${1} "${3}")
}

this="${BASH_SOURCE-$0}"
bin=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)

if ! [[ -n "${PKILL_CMD}" ]]; then
	PKILL_CMD="/usr/bin/pkill"
fi

if ! [[ -n "${QFS_HOME}" ]]; then
        QFS_HOME="/usr/local/qfs"
fi

if ! [[ -n "${QFS_CONF_DIR}" ]]; then
	QFS_CONF_DIR="${QFS_HOME}/conf"
fi


if [[ -f "${QFS_CONF_DIR}/qfs-env.sh" ]]; then
	if [ "$START_QFS_SH_DEBUG" = true ]; then
		echo "Sourcing environment variables from ${QFS_CONF_DIR}/qfs-env.sh"
    fi
    . "${QFS_CONF_DIR}/qfs-env.sh"
fi

#
# set needed environment variables if not set already
#

if ! [[ -n "${QFS_USER}" ]]; then
	QFS_USER=$USER
fi

if ! [[ -n "${METASERVER_HOST_IP}" ]]; then
	METASERVER_HOST_IP="localhost"
fi

#
# Stop the Web UI
#

echo "Stopping Meta Server Web UI on ${METASERVER_HOST_IP}"
remote_command_eval $METASERVER_HOST_IP $QFS_USER "${PKILL_CMD} -c -f qfsstatus.py"
if [ $? -eq 0 ]; then
	echo "Meta Server Web UI stopped."
else
	echo "Failed to stop Meta Server Web UI"
fi

#
# Stop the Meta Server
#
echo "Stopping Meta Server on ${METASERVER_HOST_IP}"
remote_command_eval $METASERVER_HOST_IP $QFS_USER "${PKILL_CMD} -c metaserver"
if [ $? -eq 0 ]; then
	echo "Meta Server stopped."
else
	echo "Failed to stop Meta Server"
fi

#
# Stop each Chunk Server
#
QFS_CHUNK_SERVERS_FILE="${QFS_CONF_DIR}/chunk_servers"

if [[ -f "${QFS_CHUNK_SERVERS_FILE}" ]]; then
	CHUNK_SERVER_LIST="$(< ${QFS_CHUNK_SERVERS_FILE})"
	
    for chunk_server in $CHUNK_SERVER_LIST; do
        echo "${chunk_server} - Stopping ChunkServer"
        if [[ $chunk_server = *[!\ ]* ]]; then
        	remote_command_eval $chunk_server $QFS_USER "${PKILL_CMD} -c chunkserver"
			if [ $? -eq 0 ]; then
				echo "${chunk_server} - ChunkServer stopped."
			else
				echo "${chunk_server} - Failed to stop ChunkServer"
			fi
		fi
    done
    
    echo "Done stopping Chunk Servers"
else
	echo "Could not find chunk_servers file. No Chunk Servers stopped."
fi
