#!/bin/bash
# integration_test.sh
# End-to-end integration test for the GreenDevCorp environment using Terraform and Kubernetes.

set -e

# Change to the project root directory regardless of where the script is called from
cd "$(dirname "$0")/.."

LOG_FILE="integration_test.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "Starting Integration Test for GreenDevCorp Infrastructure..."
START_TIME=$(date +%s)

# Ensure minikube is running and context is set
if ! minikube status > /dev/null 2>&1; then
    echo "Error: Minikube is not running. Please start Minikube before running this script."
    exit 1
fi

# Define the namespace based on dev.tfvars
NAMESPACE="greendev-dev"

# Inject DB password logic
if [ -z "$TF_VAR_db_password" ]; then
    if [ -f ".env" ]; then
        echo "Found .env file. Attempting to extract DB_PASSWORD..."
        # Extract DB_PASSWORD from .env, removing possible carriage returns or quotes
        ENV_PASS=$(grep '^DB_PASSWORD=' .env | cut -d '=' -f2- | tr -d '\r' | sed "s/^'//;s/'$//;s/^\"//;s/\"$//")
        if [ -n "$ENV_PASS" ]; then
            export TF_VAR_db_password="$ENV_PASS"
            echo "Success: Using DB_PASSWORD from .env file."
        fi
    fi
fi

# Final fallback if still empty
if [ -z "$TF_VAR_db_password" ]; then
    echo "Notice: TF_VAR_db_password is not set and not found in .env. Generating a temporary password..."
    export TF_VAR_db_password="secret_example_password"
fi

echo "--- Phase 1: Total Cleanup ---"
echo "Changing directory to terraform..."
cd terraform/

echo "Executing terraform destroy..."
terraform destroy -var-file="dev.tfvars" -auto-approve

echo "--- Phase 1.5: Loading Images to Minikube ---"
echo "Loading latest images into Minikube to prevent ImagePullBackOff..."
# Parse image names from tfvars or use defaults
cd ..
minikube image load musefa/app-gsx:latest musefa/nginx-gsx:latest musefa/postgres-gsx:latest || true
cd terraform/

echo "--- Phase 2: Clean Deployment ---"
echo "Executing terraform apply..."
terraform apply -var-file="dev.tfvars" -auto-approve

echo "Waiting for pods to initialize (30 seconds)..."
sleep 30

echo "Waiting for all pods in the $NAMESPACE namespace to be ready..."
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=300s

echo "--- Phase 3: Validation (Healthchecks) ---"

echo "Validation 3.1: Checking if all pods are running"
UNREADY_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$UNREADY_PODS" -gt 0 ]; then
    echo "Error: Not all pods are in Running state."
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi
echo "Success: All pods in the $NAMESPACE namespace are Running."

echo "Validation 3.2: Internal service communication (App to Database)"
APP_POD=$(kubectl get pod -l app=backend -n "$NAMESPACE" -o jsonpath="{.items[0].metadata.name}")
if kubectl exec "$APP_POD" -n "$NAMESPACE" -- nc -z -w 5 db 5432; then
    echo "Success: Internal communication verified (App can reach Database)."
else
    echo "Error: Internal communication failed (App cannot reach Database)."
    exit 1
fi

echo "Validation 3.3: External access to Nginx"
NGINX_IP=$(minikube ip)
NGINX_PORT=$(kubectl get svc nginx-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
if [ -z "$NGINX_PORT" ]; then
    echo "Nginx service might not be NodePort, trying default port 80..."
    HTTP_STATUS=$(curl -m 5 -s -o /dev/null -w "%{http_code}" http://$NGINX_IP || echo "000")
else
    HTTP_STATUS=$(curl -m 5 -s -o /dev/null -w "%{http_code}" http://$NGINX_IP:$NGINX_PORT || echo "000")
fi

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 502 ]; then
    echo "Success: External access to Nginx is working (HTTP Status: $HTTP_STATUS)."
else
    echo "Warning/Error: External access returned HTTP Status $HTTP_STATUS."
fi

echo "Validation 3.4: NetworkPolicies block unauthorized traffic"
echo "Creating an isolated temporary pod to test DB access..."
kubectl run temp-isolated-pod --image=alpine --restart=Never -n "$NAMESPACE" --labels="role=isolated" -- sleep 3600
kubectl wait --for=condition=ready pod/temp-isolated-pod -n "$NAMESPACE" --timeout=60s

echo "Attempting to connect to db from the isolated pod..."
if kubectl exec temp-isolated-pod -n "$NAMESPACE" -- nc -z -w 3 db 5432; then
    echo "Error: NetworkPolicy validation failed. Unauthorized pod reached the database."
    kubectl delete pod temp-isolated-pod -n "$NAMESPACE"
    exit 1
else
    echo "Success: NetworkPolicy validation passed. Unauthorized traffic was blocked."
fi

echo "Cleaning up temporary pod..."
kubectl delete pod temp-isolated-pod -n "$NAMESPACE"

echo "--- Phase 4: Recording Metrics ---"
cd ..
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Integration test completed successfully."
echo "Total deployment and validation time: $DURATION seconds."

# Write metrics to a separate file
echo "Deployment duration: $DURATION seconds" > test_metrics.txt

echo "Integration test finished."
exit 0
