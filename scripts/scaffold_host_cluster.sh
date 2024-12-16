AKS_RESOURCE_GROUP=ultron-rg-dev
AKS_REGION=northeurope
AKS_VNET=ultron-aks-vnet-dev
AKS_VNET_ADDRESS_PREFIX=10.0.0.0/8
AKS_VNET_SUBNET_DEFAULT=ultron-aks-subnet-default
AKS_VNET_SUBNET_DEFAULT_PREFIX=10.240.0.0/16
AKS_VNET_SUBNET_VIRTUALNODES=ultron-aks-subnet-virtual-nodes
AKS_VNET_SUBNET_VIRTUALNODES_PREFIX=10.241.0.0/16

# Register Required Providers
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute

# Create Resource Group
az group create --location ${AKS_REGION} \
                --name ${AKS_RESOURCE_GROUP}

# Create Virtual Network & default Subnet
az network vnet create -g ${AKS_RESOURCE_GROUP} \
                       -n ${AKS_VNET} \
                       --address-prefix ${AKS_VNET_ADDRESS_PREFIX} \
                       --subnet-name ${AKS_VNET_SUBNET_DEFAULT} \
                       --subnet-prefix ${AKS_VNET_SUBNET_DEFAULT_PREFIX} 

# Create Virtual Nodes Subnet in Virtual Network
az network vnet subnet create \
    --resource-group ${AKS_RESOURCE_GROUP} \
    --vnet-name ${AKS_VNET} \
    --name ${AKS_VNET_SUBNET_VIRTUALNODES} \
    --address-prefixes ${AKS_VNET_SUBNET_VIRTUALNODES_PREFIX}

# Get Virtual Network default subnet id
AKS_VNET_SUBNET_DEFAULT_ID=$(az network vnet subnet show \
                           --resource-group ${AKS_RESOURCE_GROUP} \
                           --vnet-name ${AKS_VNET} \
                           --name ${AKS_VNET_SUBNET_DEFAULT} \
                           --query id \
                           -o tsv)

echo ${AKS_VNET_SUBNET_DEFAULT_ID}

# Check if User Access Administrator role is assigned
# role_name="User Access Administrator"

# assigned_roles=$(az role assignment list --assignee $(az ad signed-in-user show --query objectId -o tsv) --query "[?roleDefinitionName=='$role_name']" -o tsv)

# if [[ -n $assigned_roles ]]; then
#     # Create Azure AD Group (Requires: User Access Administrator Role)
#     AKS_AD_AKSADMIN_GROUP_ID=$(az ad group create --display-name aksadmins --mail-nickname aksadmins --query objectId -o tsv)    

#     echo $AKS_AD_AKSADMIN_GROUP_ID

#     # Create Azure AD AKS Admin User (Requires: User Access Administrator Role)
#     # Replace with your AD Domain - aksadmin1@stacksimplifygmail.onmicrosoft.com
#     AKS_AD_AKSADMIN1_USER_OBJECT_ID=$(az ad user create \
#     --display-name "AKS Admin1" \
#     --user-principal-name aksadmin1@stacksimplifygmail.onmicrosoft.com \
#     --password @AKSDemo123 \
#     --query objectId -o tsv)

#     echo $AKS_AD_AKSADMIN1_USER_OBJECT_ID

#     # Associate aksadmin User to aksadmins Group
#     az ad group member add --group aksadmins --member-id $AKS_AD_AKSADMIN1_USER_OBJECT_ID
# fi

# Create Log Analytics Workspace
AKS_MONITORING_LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace create --resource-group ${AKS_RESOURCE_GROUP} \
                                           --workspace-name ultron-loganalytics-workspace-dev \
                                           --query id \
                                           -o tsv)

echo $AKS_MONITORING_LOG_ANALYTICS_WORKSPACE_ID

# Get Azure Active Directory (AAD) Tenant ID
AZURE_DEFAULT_AD_TENANTID=$(az account show --query tenantId --output tsv)

echo $AZURE_DEFAULT_AD_TENANTID

# Set Cluster Name
AKS_CLUSTER=ultron-aks-dev

echo $AKS_CLUSTER

# Create AKS cluster 
az aks create --resource-group ${AKS_RESOURCE_GROUP} \
              --name ${AKS_CLUSTER} \
              --enable-managed-identity \
              --admin-username ultronadmin \
              --generate-ssh-keys \
              --network-plugin azure \
              --enable-aad \
              --enable-addons monitoring \

#              --workspace-resource-id ${AKS_MONITORING_LOG_ANALYTICS_WORKSPACE_ID}
#              --enable-cluster-autoscaler \
#              --node-count 1 \
#              --min-count 1 \
#              --max-count 100 \
#              --vnet-subnet-id ${AKS_VNET_SUBNET_DEFAULT_ID} \
#              --service-cidr 10.0.0.0/16 \
#              --dns-service-ip 10.0.0.10 \
#              --node-osdisk-size 30 \
#              --node-vm-size Standard_DS2_v2 \
#              --nodepool-labels nodepool-type=system nodepoolos=linux app=system-apps \
#              --nodepool-name systempool \
#              --nodepool-tags nodepool-type=system nodepoolos=linux app=system-apps \
#              --enable-ahub \
#              --zones {1,2,3} \
#              --ssh-key-value  ${AKS_SSH_KEY_LOCATION} \
#              --aad-admin-group-object-ids ${AKS_AD_AKSADMIN_GROUP_ID}\
#              --aad-tenant-id ${AZURE_DEFAULT_AD_TENANTID} \

# Configure Credentials
# az aks get-credentials --name ${AKS_CLUSTER}  --resource-group ${AKS_RESOURCE_GROUP} 

# Cluster Info
# kubectl cluster-info

# List Node Pools
# az aks nodepool list --cluster-name ${AKS_CLUSTER} --resource-group ${AKS_RESOURCE_GROUP} -o table

# List which pods are running in system nodepool from kube-system namespace
# kubectl get pod -o=custom-columns=NODE-NAME:.spec.nodeName,POD-NAME:.metadata.name -n kube-system