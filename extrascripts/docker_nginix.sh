# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
sudo apt-get update
sudo apt-get install docker-compose

#or

#for docker compose
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose