# This is based on MSFT provided samples. 
# Detailed information can be found below
# https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-app
# Pre-requisites
# docker engine ; container runtime
# https://www.docker.com/get-started
# az ; azure cli  
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# az aks install-cli ; kubernetes cli

# Git clone sample app for our demo
# Sample app contains the base image for nginx+flask, the frontend app and a redis instance
git clone https://github.com/Azure-Samples/azure-voting-app-redis.git

# use docker-compose to build, creates, starts the container locally.
# -d is detach mode: runs in the background
cd azure-voting-app-redis
docker-compose up -d

# check if image is available
docker images

# check if container is running
docker ps

# Test the app by browsing endpoint
http://localhost:8080

# To deploy the container to AKS, first lets create a resource group for our demo env
az group create --name "aksdemo-rg" --location australiaeast

# And an Azure Container Registry for storing our container images in a private repository
az acr create --resource-group "aksdemo-rg" --name aksdemoacr --sku Basic

# After deployment, login to ACR to be able to run query
az acr login --name aksdemoacr

# To use azure-vote-front image with ACR, the image needs to be tagged with the login server address of the registry. 
# Get the login server address
az acr list --resource-group aksdemo-rg --query "[].{acrLoginServer:loginServer}" --output table

# Tag image with ACR Login Server and add a release version. Im calling it v1
# https://docs.docker.com/engine/reference/commandline/tag/
docker tag azure-vote-front aksdemoacr.azurecr.io/azure-vote-front:v1

# Push image to ACR
docker push aksdemoacr.azurecr.io/azure-vote-front:v1

# Check container repository for all available Tags
az acr repository show-tags --name aksdemoacr --repository azure-vote-front --output table

# Before deploying AKS create the Service Principal that your cluster will use
# https://docs.microsoft.com/en-au/azure/aks/kubernetes-service-principal
az ad sp create-for-rbac --skip-assignment

# Also, make sure AKS can pull images from ACR by giving the SP permission to pull images
# To create a role, use the service princiapal (app) id and the id of the ACR 
az acr show --resource-group aksdemo-rg --name aksdemoacr --query "id" --output tsv
az role assignment create --assignee <app_ID> --scope <acr_ID> --role acrpull

# Finally deploy the AKS Cluster
az aks create --resource-group aksdemo-rg --name aksdemoaks --node-count 1 --service-principal <app_ID> --client-secret <app_Secret> --generate-ssh-keys

# Connect to cluster
az aks get-credentials --resource-group aksdemo-rg --name aksdemoaks

# Check for nodes
kubectl get nodes

# Finally deploy your container to AKS
# Edit the file azure-vote-all-in-one-redis.yaml and update the azure-vote-front image to point to the ACR endpoint (line 47)
# image: aksdemoacr.azurecr.io/azure-vote-front:v1
# Create the resource in AKS
kubectl apply -f azure-vote-all-in-one-redis.yaml

# You can use the cmd below to monitor the progress
kubectl get service azure-vote-front --watch

# Check for running pods
kubectl get pods

# To manually scale a pod, use the cmd below. This will scale up to 3 replicas
kubectl scale --replicas=3 deployment/azure-vote-front

# You can also autoscale pods based on cpu utilisation
kubectl autoscale deployment azure-vote-front --cpu-percent=50 --min=3 --max=10

# We can also manually scale the nodes 
# autoscale is in preview, but available if using AKS 1.12.5+
az aks scale --resource-group aksdemo-rg --name aksdemoaks --node-count 3


 



