#!/usr/bin/env bash
set -euo pipefail


########################
# Foundation
helm upgrade --install foundation ./charts/foundation \
  -f values/product/dev/product/foundation-values.yaml \
  --wait
########################
# Istio base
helm upgrade --install istio-base ./charts/base \
  -n istio-system \
  -f ./charts/base/values.yaml \
  --skip-crds \
  --wait
########################
# helm status istio-base -n istio-system
# helm get all istio-base -n istio-system
########################
# Istiod
helm upgrade --install istiod ./charts/istiod \
  -n istio-system \
  -f values/product/dev/istiod-values.yaml \
  --wait --timeout 10m
########################
# Istio Ingress Gateway
helm upgrade --install istio-ingressgateway ./charts/gateway \
  -n istio-system \
  -f values/product/dev/istio-ingressgateway-values.yaml \
  --wait --timeout 10m
########################
# Istio Egress Gateway
helm upgrade --install istio-egressgateway ./charts/gateway \
  -n istio-system \
  -f values/product/dev/istio-egressgateway-values.yaml \
  --wait --timeout 10m
########################
# secrets for aib-system
kubectl apply -f scripts/secrets.yaml
########################
# MINIO
export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=admin123

helm upgrade --install minio charts/minio \
  --namespace aib-data \
  --set rootUser=$MINIO_ROOT_USER \
  --set rootPassword=$MINIO_ROOT_PASSWORD \
  -f values/product/dev/minio.yaml
########################
# MYSQL (external DB for MLRun — replaces the mysql embedded in mlrun-ce)
helm upgrade --install mysql charts/mysql \
  --namespace aib-system \
  -f values/product/dev/mysql.yaml
########################
# MLRUN
helm upgrade --install mlrun charts/mlrun-ce \
  --namespace aib-system \
  -f values/product/dev/mlrun.yaml
########################
helm dependency build charts/aib-platform

helm upgrade --install aib-platform charts/aib-platform \
  -f values/product/dev/aib-platform-values.yaml \
  -n istio-system
########################
