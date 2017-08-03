#!/bin/bash

# Create route
function create_route() {
  echo $1
  curl -d "$(cat | jq -r -c ". | @json")" $1/routes
}
function delete_routes() {
  echo $1
  routes=( $(curl $1/routes | jq -r '.[].id') )
  for route in ${routes[@]}; do
    curl -X DELETE $1/routes/$route
  done
}

if [[ -z "$@" ]]; then
  # LOGSPOUTS=$(rancher inspect logspout/logspout | jq -r '.publicEndpoints[].ipAddress')
  # rancher inspect logspout/logspout | jq -r '.publicEndpoints[] | .ipAddress + ":" + (.port | tostring) '
  LOGSPOUTS=( $(rancher inspect logspout/logspout | jq -r '.publicEndpoints[] | [.ipAddress, .port | tostring] | join(":")') )
  for ip in ${LOGSPOUTS[@]}; do
    create_route $ip
  done
else
  test -z "$@" && echo "invalid logspout address" && exit 1
  # create_route "$@"
fi

IPS=( $(rancher inspect logspout/logspout | jq -r '.publicEndpoints[] | [.ipAddress, .port | tostring] | join(":")') )
| jq -r '.[].id'
