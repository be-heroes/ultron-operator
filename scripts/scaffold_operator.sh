# Create and navigate to the project directory
mkdir ultron-operator
cd ultron-operator

# Initialize the operator project
operator-sdk init --domain 2mind.dk --repo github.com/be-heroes/ultron-operator

# Create APIs and controllers
operator-sdk create api --group ultron --version v1alpha1 --kind Ultron --resource --controller
operator-sdk create api --group ultron --version v1alpha1 --kind UltronAttendant --resource --controller
operator-sdk create api --group ultron --version v1alpha1 --kind UltronObserver --resource --controller

# Generate manifests and code
make manifests
make generate

# Build and push the operator image
make docker-build IMG=zaradarbh/ultron-operator:latest
make docker-push IMG=zaradarbh/ultron-operator:latest

# Deploy the operator to the cluster
make deploy IMG=zaradarbh/ultron-operator:latest

# Apply custom resources
kubectl apply -f config/samples/ultron_v1alpha1_ultron.yaml
kubectl apply -f config/samples/ultron_v1alpha1_ultronattendant.yaml
kubectl apply -f config/samples/ultron_v1alpha1_ultronobserver.yaml

# Verify resources
kubectl get ultron
kubectl get ultronattendant
kubectl get ultronobserver
