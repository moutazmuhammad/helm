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
# Bootstrap Secrets — must be filled in BEFORE running this script:
#   - mysql-credentials         (aib-data)
#   - seaweedfs-db-credentials  (aib-data)
#   - mlrun-db                  (aib-system, DSN with embedded MySQL password)
#   - nuclio-gar-push           (aib-system, registry pull/push)
# See scripts/secrets.yaml for placeholders and the README at the top of
# that file for how to mint them.
kubectl apply -f scripts/secrets.yaml

# Sanity check: confirm every required Secret exists and has no REPLACE_ME
# tokens lingering. The chart installs depend on these being real values.
for entry in \
  "aib-data/mysql-credentials/mysql-root-password" \
  "aib-data/mysql-credentials/mysql-replication-password" \
  "aib-data/seaweedfs-db-credentials/mariadb-password" \
  "aib-system/mlrun-db/dsn"; do
  IFS=/ read -r ns name key <<<"$entry"
  val=$(kubectl get secret "$name" -n "$ns" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || true)
  if [[ -z "$val" || "$val" == *REPLACE_ME* ]]; then
    echo "ERROR: Secret $ns/$name key '$key' is empty or still contains REPLACE_ME." >&2
    echo "       Edit scripts/secrets.yaml, replace the placeholder, and re-apply." >&2
    exit 1
  fi
done
########################
# MYSQL (external DB for MLRun and SeaweedFS, deployed in aib-data —
# replaces the mysql embedded in mlrun-ce. Provisions the seaweedfs
# database/user via the initdb hook.)
helm upgrade --install mysql charts/mysql \
  --namespace aib-data \
  -f values/product/dev/mysql.yaml \
  --wait --timeout 10m
########################
# SeaweedFS — production S3 store, replaces MinIO
helm upgrade --install seaweedfs charts/seaweedfs \
  --namespace aib-data \
  -f values/product/dev/seaweedfs.yaml \
  --wait --timeout 15m
########################
# Sync the SeaweedFS S3 admin keys into aib-system as the
# minio-credentials / mlpipeline-minio-artifact Secrets MLRun expects.
ADMIN_KEY=$(kubectl get secret seaweedfs-s3-secret -n aib-data \
  -o jsonpath='{.data.admin_access_key_id}' | base64 -d)
ADMIN_SECRET=$(kubectl get secret seaweedfs-s3-secret -n aib-data \
  -o jsonpath='{.data.admin_secret_access_key}' | base64 -d)

kubectl create secret generic minio-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$ADMIN_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$ADMIN_SECRET" \
  --namespace aib-system \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic mlpipeline-minio-artifact \
  --from-literal=accesskey="$ADMIN_KEY" \
  --from-literal=secretkey="$ADMIN_SECRET" \
  --namespace aib-system \
  --dry-run=client -o yaml | kubectl apply -f -
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
