#!/bin/bash
set -e

usage() {
  printf "Usage:\t\t$0 OPTION\n\n\tOptions:\t-a\t\tDeploy\n\t\t\t-d\t\tDestroy\n"
  exit 2
}

deploy() {
  terraform init
  terraform apply -auto-approve -target helm_release.cert_manager
  terraform apply -auto-approve -target kubernetes_manifest.cluster_issuer \
  -target helm_release.prometheus -target helm_release.ingress_nginx \
  -target helm_release.mongodb
  terraform apply -auto-approve
}

destroy() {
  terraform destroy -auto-approve
}

[ $(which terraform) ] || { printf "terraform binary missing!\n"; exit 1; }
[ $1 ] || usage
case "$1" in
        -a )    deploy  ;;
        -d )    destroy ;;
        * )     usage  ;;
esac
exit 0
