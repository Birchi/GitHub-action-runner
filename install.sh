#!/bin/bash
##
# Variables
##
directory=$(pwd)/runner

##
# Function
##
function usage(){
    cat <<EOF
This script installs a github action runner.
  
Options:
  -d, --directory       Defines the install directory of a github action runner. Default value is current directory.
  -h, --help            Shows this message.
  
Examples:
  $(dirname $0)/install.sh
EOF
}

function parse_cmd_args() {
    args=$(getopt --options d:h \
                  --longoptions directory:,help -- "$@")
    
    if [[ $? -ne 0 ]]; then
        echo "Failed to parse arguments!" && usage
        exit 1;
    fi

    while test $# -ge 1 ; do
        case "$1" in
            -h | --help) usage && exit 0 ;;
            -d | --directory) directory="$(eval echo $2)" ; shift 1 ;;
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

    if ! [ -d ${directory} ] ; then
        mkdir -p ${directory}
    fi

    download_urls=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | python3 -c "${download_url_praser}")
    for download_url in $download_urls ; do
        file_path=${directory}/$(basename $download_url)
        echo "Starting to download ${download_url}"
        curl -s -L $download_url --output ${file_path}
        echo "Unpacking ${file_path} to ${directory}"
        tar xzf ${file_path} -C ${directory}
        echo "Removing ${file_path}"
        rm ${file_path}
    done
}
