#!/bin/bash

if [ "$(basename "$(pwd)")" != "taskrpad-server" ]
then
    echo "Please run cc_server.sh from the taskrpad repo directory!"
    echo "i.e. ./scripts/taskrpad.sh [options] arguments"
    exit 1
fi

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

if ! (return 0 2> /dev/null); then
    # A better class of script...
    set -o errexit      # Exit on most errors (see the manual)
    set -o nounset      # Disallow expansion of unset variables
    set -o pipefail     # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace         # Ensure the error trap handler is inherited

selected_container=""

function script_usage() {
    cat << EOF
TaskrPad deployment script, used to control the docker functions of the project
    Usage:
            taskrpad.sh [options] arguments
    Options:
        -h | --help              Displays this help
        -v | --verbose           Displays verbose output, display docker logs
    Arugments:
        build                    Build docker containers
        start                    Run silently unless we encounter an error
        stop                     Stop running docker containers
        restart                  Restart all runnign docker containers
        clean                    Removes all docker related data [Volumes, Containers and Networks]
        clean-db [Disabled]      emove db container and volume
        test_unit                Run unit test suite
        test_integration         Run integration test suite
        refresh-env-file         Refresh .env file with env file
        swagger                  Generate Swagger documentation yaml
EOF
}

function test-unit() {
    echo "Running Go Unit tests..."
    go test ./... -v
}

function test-integration() {
    echo "Running Integration tests..."
    # shellcheck source=/dev/null
    source taskrpad_pyenv/bin/activate && pytest ./integration_tests/
}

function fetch_valid_containers() {
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        if [ "$param" != "-v" ] && [ "$param" != "-h" ]; then
            if grep "container_name:" "$(pwd)/docker-compose.yaml" | grep -q "$param"; then
                if [ -z "$selected_container" ]; then
                    selected_container="$param"
                else
                    selected_container="$selected_container $param"
                fi
            fi
        fi
    done
}

function build() {
    echo "Building TaskrPad docker images..."
    COMPOSE_BAKE=true docker compose -f "$(pwd)/docker-compose-convert.yaml" build "$selected_container"

    # delete dangling images
    # dangling_images=$(docker images -f "dangling=true" -q)
    # if [[ -n "$dangling_images" ]]; then
    #     docker rmi "$dangling_images" #delete dangling images
    # fi
    
    docker image prune -f --filter "until=24h"

    # bandaid fix to growing build cache size after many build cycles
    docker builder prune -f --filter "until=24h" 
}

# function protobuf_compile() {
#     protoc -I services/control/protos/ services/control/protos/vehicle_control.proto \
#            --go_out=services/control/protos/ --go-grpc_out=services/control/protos/
# 	protoc -I services/heartbeat/protos/ services/heartbeat/protos/vehicle_heartbeat.proto \
#            --go_out=services/heartbeat/protos/ --go-grpc_out=services/heartbeat/protos/
# 	protoc -I services/ingress/protos/ services/ingress/protos/vehicle_ingress.proto \
#            --go_out=services/ingress/protos/  --go-grpc_out=services/ingress/protos/
# }

function start() {
    if [ "$is_verbose" = "true" ]; then
        echo "Starting TaskrPad docker containers [verbose]..."
        docker compose -f "$(pwd)/docker-compose-convert.yaml" up "$selected_container"
    else
        echo "Starting TaskrPad docker containers..."
        docker compose -f "$(pwd)/docker-compose-convert.yaml" up -d "$selected_container"
    fi
}

function restart() {
    echo "Restarting TaskrPad docker containers..."
    docker compose down
    docker compose -f "$(pwd)/docker-compose-convert.yaml" up -d "$selected_container"
}

function stop() {
    echo "Stopping active TaskrPad docker containers..."
    docker compose stop "$selected_container"
}

function clean() {
    echo "Taking down active TaskrPad docker containers..."
    docker compose down
    echo "Docker system prune..."
    # TODO: add confirmation bypass instead of forcing confirmation
    docker system prune -a -f
}

# function clean-db() {
#     echo "Removing saved postgres db volume and container..."
#     docker compose down
#     docker volume rm gitcollab_db
# }

function refresh-env-file() {
    echo "Refreshing $(pwd)/.env..."
    cp "$(pwd)/env" "$(pwd)/.env"
    chmod 777 "$(pwd)/.env" # change to write permission
}

function generate-swagger() {
    echo "Generating Swagger yaml documentation inside $(pwd)/swagger/"
    go install github.com/swaggo/swag/cmd/swag@latest
    #mkdir -p ./swagger
    swag init --output swagger --dir cmd/taskrpad #,services/tasks,services/device,services/image,services/login
}

function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h | --help)
                script_usage
                exit 0
                ;;
            -v | --verbose)
                is_verbose=true
                ;;
            test_unit)
                test-unit
                exit 0
                ;;
            test_integration)
                start
                test-integration
                stop
                exit 0
                ;;
            build)
                #protobuf_compile
                docker compose convert > "$(pwd)/docker-compose-convert.yaml"
                build
                ;;
            start)
                docker compose convert > "$(pwd)/docker-compose-convert.yaml"
                start
                ;;
            restart)
                docker compose convert > "$(pwd)/docker-compose-convert.yaml"
                restart
                ;;
            stop)
                stop
                ;;
            clean)
                clean
                echo "done!"
                exit 0
                ;;
            # clean-db)
            #     clean-db
            #     echo "done!"
            #     exit 0
            #     ;;
            refresh-env-file)
                refresh-env-file
                ;;
            swagger)
                generate-swagger
                ;;
            *)
                if ! echo "$selected_container" | grep -q "$param"; then
                    echo "Invalid parameter was provided: $param"
                    exit 1
                fi
                ;;
        esac
    done
}

function main() {

    if [ $# -eq 0 ] || [[ "$1" = "-v" && $# -eq 1 ]]
    then
        echo "No arguments supplied!"
        echo ""
        script_usage
    fi

    is_verbose=false

    fetch_valid_containers "$@"

    parse_params "$@"
}

if [ ! -f "$(pwd)/env" ]; then
    echo "env missing, what did you do!"
    exit 1
fi

if [ ! -f "$(pwd)/.env" ]; then
    cp "$(pwd)/env" "$(pwd)/.env"
    chmod 777 "$(pwd)/.env" # TODO: change to write permission
fi

main "$@"
echo "done!"
