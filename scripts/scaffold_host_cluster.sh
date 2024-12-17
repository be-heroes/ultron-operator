# Initialize Variables
ULTRON_REGION=northeurope
ULTRON_ENVIRONMENT=dev
ULTRON_RESOURCE_GROUP=ultron-rg-$ULTRON_ENVIRONMENT
ULTRON_AKS_CLUSTER=ultron-aks-$ULTRON_ENVIRONMENT
ULTRON_AKS_VNET=ultron-aks-vnet-$ULTRON_ENVIRONMENT
ULTRON_AKS_VNET_ADDRESS_PREFIX=10.0.0.0/8
ULTRON_AKS_VNET_SUBNET_DEFAULT=ultron-aks-subnet-default-$ULTRON_ENVIRONMENT
ULTRON_AKS_VNET_SUBNET_DEFAULT_PREFIX=10.240.0.0/16
ULTRON_AKS_VNET_SUBNET_VIRTUALNODES=ultron-aks-subnet-virtual-nodes-$ULTRON_ENVIRONMENT
ULTRON_AKS_VNET_SUBNET_VIRTUALNODES_PREFIX=10.241.0.0/16

# Register Required Providers
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute

# Create Resource Group
az group create --location ${ULTRON_REGION} \
                --name ${ULTRON_RESOURCE_GROUP}

# Create Virtual Network & default Subnet
az network vnet create -g ${ULTRON_RESOURCE_GROUP} \
                       -n ${ULTRON_AKS_VNET} \
                       --address-prefix ${ULTRON_AKS_VNET_ADDRESS_PREFIX} \
                       --subnet-name ${ULTRON_AKS_VNET_SUBNET_DEFAULT} \
                       --subnet-prefix ${ULTRON_AKS_VNET_SUBNET_DEFAULT_PREFIX} 

# Create Virtual Nodes Subnet in Virtual Network
az network vnet subnet create \
    --resource-group ${ULTRON_RESOURCE_GROUP} \
    --vnet-name ${ULTRON_AKS_VNET} \
    --name ${ULTRON_AKS_VNET_SUBNET_VIRTUALNODES} \
    --address-prefixes ${ULTRON_AKS_VNET_SUBNET_VIRTUALNODES_PREFIX}

# Get Virtual Network default subnet id
ULTRON_AKS_VNET_SUBNET_DEFAULT_ID=$(az network vnet subnet show \
                           --resource-group ${ULTRON_RESOURCE_GROUP} \
                           --vnet-name ${ULTRON_AKS_VNET} \
                           --name ${ULTRON_AKS_VNET_SUBNET_DEFAULT} \
                           --query id \
                           -o tsv | tr -d '\r')

# Check if User Access Administrator role is assigned
user_upn=$(az ad signed-in-user show --query userPrincipalName -o tsv)
trimmed_user_upn="$(echo -e "${user_upn}" | sed -e 's/[[:space:]]*$//')"
assigned_roles=$(az role assignment list --assignee $trimmed_user_upn --query "[?roleDefinitionName=='User Access Administrator']" -o tsv)

if [[ -n $assigned_roles ]]; then
  # Create Azure AD Group (Requires: User Access Administrator Role)
  ULTRON_AKS_AD_AKSADMIN_GROUP_ID=$(az ad group create --display-name aksadmins --mail-nickname aksadmins --query id -o tsv | tr -d '\r')
  SIGNED_IN_USER_ID=$(az ad signed-in-user show --query id -o tsv | tr -d '\r')

  # Set current user as owner of aksadmins Group
  az ad group owner add --group aksadmins --owner-object-id $SIGNED_IN_USER_ID

  # Create Azure AD AKS Admin User (Requires: User Access Administrator Role)
  ULTRON_AKS_AD_AKSADMIN1_USER_OBJECT_ID=$(az ad user create \
                                  --display-name "AKS Admin1" \
                                  --user-principal-name aksadmin1@epwispcompute.onmicrosoft.com \
                                  --password @AKSDemo123 \
                                  --query id -o tsv | tr -d '\r')

  # Associate aksadmin User to aksadmins Group
  az ad group member add --group aksadmins --member-id $ULTRON_AKS_AD_AKSADMIN1_USER_OBJECT_ID
fi

# Create Log Analytics Workspace
ULTRON_AKS_MONITORING_LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace create --resource-group ${ULTRON_RESOURCE_GROUP} \
                                           --workspace-name ultron-loganalytics-workspace-dev \
                                           --query id \
                                           -o tsv | tr -d '\r')

# Get Azure Active Directory (AAD) Tenant ID
ULTRON_AZURE_DEFAULT_AD_TENANTID=$(az account show --query tenantId --output tsv | tr -d '\r')

# Create AKS cluster 
az aks create --resource-group ${ULTRON_RESOURCE_GROUP} \
              --name ${ULTRON_AKS_CLUSTER} \
              --enable-managed-identity \
              --admin-username ultronadmin \
              --generate-ssh-keys \
              --network-plugin azure \
              --enable-aad \
              --enable-addons monitoring \
              --enable-cluster-autoscaler \
              --node-count 1 \
              --min-count 1 \
              --max-count 10 \
              --aad-tenant-id ${ULTRON_AZURE_DEFAULT_AD_TENANTID} \
              --aad-admin-group-object-ids ${ULTRON_AKS_AD_AKSADMIN_GROUP_ID} \
              --workspace-resource-id ${ULTRON_AKS_MONITORING_LOG_ANALYTICS_WORKSPACE_ID} \
              --vnet-subnet-id ${ULTRON_AKS_VNET_SUBNET_DEFAULT_ID} \
              --service-cidr 10.0.0.0/16 \
              --dns-service-ip 10.0.0.10 \
              --node-osdisk-size 30 \
              --node-vm-size Standard_DS2_v2 \
              --nodepool-labels nodepool-type=system nodepoolos=linux app=system-apps \
              --nodepool-name systempool \
              --nodepool-tags nodepool-type=system nodepoolos=linux app=system-apps

# Configure Credentials
az aks get-credentials --name ${ULTRON_AKS_CLUSTER}  --resource-group ${ULTRON_RESOURCE_GROUP} 

# Cluster Info
kubectl cluster-info

# List Node Pools
az aks nodepool list --cluster-name ${ULTRON_AKS_CLUSTER} --resource-group ${ULTRON_RESOURCE_GROUP} -o table

# List which pods are running in system nodepool from kube-system namespace
kubectl get pod -o=custom-columns=NODE-NAME:.spec.nodeName,POD-NAME:.metadata.name -n kube-system