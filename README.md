# Notes: 

## Updates:
- Updated the MLRun Helm chart by modifying the Nuclio subchart service configuration to support ClusterIP type, instead of being restricted to NodePort only.
    * `aib-plus-dev-work/charts/mlrun-ce/charts/nuclio/templates/service/dashboard.yaml`
- Updated the MLRun Helm chart by modifying DB templates to support an external S3 service (installed from seperate chart)
    * `charts/mlrun-ce/charts/mlrun/templates/db-configmap-init.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-configmap.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-deployment.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-exporter-service.yml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-secret.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-service.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/mlrun-db-pvc.yaml` 
    * `charts/mlrun-ce/charts/mlrun/values.yaml` 
    * `charts/mlrun-ce/templates/_helpers.tpl` 
