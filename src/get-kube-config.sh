#!/bin/bash

RADDR=$1
OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

mkdir ./src/kube-creds/

scp ${OPTS} ${RADDR}:/root/.kube/config ./src/kube-creds/kube.config
scp ${OPTS} ${RADDR}:/root/.minikube/ca.crt ./src/kube-creds/ca.crt
scp ${OPTS} ${RADDR}:/root/.minikube/profiles/minikube/client.crt ./src/kube-creds/client.crt
scp ${OPTS} ${RADDR}:/root/.minikube/profiles/minikube/client.key ./src/kube-creds/client.key

sed -i "s/\/root\/\.minikube\/ca\.crt/\.\/ca.crt/g; s/\/root\/\.minikube\/profiles\/minikube\/client\.crt/\.\/client\.crt/g; s/\/root\/\.minikube\/profiles\/minikube\/client\.key/\.\/client\.key/g" ./src/kube-creds/kube.config
