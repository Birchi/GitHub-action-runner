#!/bin/bash
##
# Variables
##
directory=${HOME}/runners
name=
repository=
token=

##
# Function
##
function usage(){
    cat <<EOF
This script installs a github action runner.
  
Options:
  -d, --directory       Defines the install directory of a github action runner. Default value is ${HOME}/runners.
  -n, --name            Defines name of a runner.
  -r, --repository      Defines url of a repository.
  -t, --token           Defines registration token for repository.
  -h, --help            Shows this message.
  
Examples:
  $(dirname $0)/install.sh --name NAME --repository REPO --token TOKEN
  $(dirname $0)/install.sh -n NAME -r REPO -t TOKEN
EOF
}

function parse_cmd_args() {
    args=$(getopt --options d:n:r:t:h \
                  --longoptions directory:,name:,repository:,token:,help -- "$@")
    
    if [[ $? -ne 0 ]]; then
        echo "Failed to parse arguments!" && usage
        exit 1;
    fi

    while test $# -ge 1 ; do
        case "$1" in
            -h | --help) usage && exit 0 ;;
            -d | --directory) directory="$(eval echo $2)" ; shift 1 ;;
            -n | --name) name="$(eval echo $2)" ; shift 1 ;;
            -r | --repository) repository="$(eval echo $2)" ; shift 1 ;;
            -t | --token) token="$(eval echo $2)" ; shift 1 ;;
            --) ;;
             *) ;;
        esac
        shift 1
    done 
}

##
# Main
##
{

    parse_cmd_args "$@"

    download_url_praser=$(cat <<EOF
import sys
import json
import platform

def normalize_os_n_arch():
    os_name = platform.system()
    if os_name == "Darwin":
        os_name = "osx"
    elif os_name == "Linux":
        os_name = "linux"
    elif os_name == "Windows":
        os_name = "win"
    else:
        raise Exception("OS {} is not supported yet.".format(os_name))
    arch = platform.machine().lower()
    if arch == "x86_64":
        arch = "x64"
    return  "{}-{}".format(os_name, arch)

if __name__ == "__main__":
    json_object = json.load(sys.stdin)
    if "assets" in json_object.keys():
        os_n_arch = normalize_os_n_arch()
        for asset in json_object["assets"]:
            if os_n_arch in asset.get("name", ""):
                print(asset.get("browser_download_url", ""))
    else:
        raise Exception(json_object.get("message", "Something went wrong"))
EOF
)
    if [[ "${name}" == "" ]] ; then
        echo "Please, define a name via --name NAME"
        exit 1
    fi
    
    if [[ "${repository}" == "" ]] ; then
        echo "Please, define an URL of a repository via --repository REPO"
        exit 1
    fi

    if [[ "${token}" == "" ]] ; then
        echo "Please, define a token via --token TOKEN"
        exit 1
    fi

    runner_directory=${directory}/${name}
    if ! [ -d ${runner_directory} ] ; then
        mkdir -p ${runner_directory}
    fi
    
    download_urls=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | python3 -c "${download_url_praser}")
    for download_url in $download_urls ; do
        file_path=${runner_directory}/$(basename $download_url)
        echo "Starting to download ${download_url}"
        curl -s -L ${download_url} --output ${file_path}
        echo "Unpacking ${file_path} to ${runner_directory}"
        tar xzf ${file_path} -C ${runner_directory}
        echo "Removing ${file_path}"
        rm ${file_path}
        cd ${runner_directory}
        ./config.sh --unattended --url ${repository} --token ${token} --replace --name ${name}
        escaped_runner_directory=$(echo "${runner_directory}" | sed 's#\/#\\/#g')
        if [ -d /etc/systemd/system ] ; then
            cat ${runner_directory}/bin/actions.runner.service.template | grep -v "User=" | sed "s/{{RunnerRoot}}/${escaped_runner_directory}/g" | sed "s/{{Description}}/Github action runners - ${runner_directory}/g" > /etc/systemd/system/github-runner-${name}.service
            systemctl daemon-reload
            systemctl start github-runner-${name}.service
            systemctl enable github-runner-${name}.service
        fi
    done
}
