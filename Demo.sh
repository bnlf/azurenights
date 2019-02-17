# Pre-requisites
# docker ; container runtime
# az ; azure cli  
# az aks install-cli ; kubernetes cli

# Part 1 - Prepare App for AKS

# Git clone sample app
# Sample app contains the base image for nginx+flask, the frontend app and a redis instance
git clone https://github.com/Azure-Samples/azure-voting-app-redis.git

# Cd to Dir & Build image using Docker-Compose
# docker-compose up: Builds, (re)creates, starts, and attaches to containers for a service.
# -d is detach mode: runs in the background
cd azure-voting-app-redis
docker-compose up -d

# list 
docker images

# list running processes
docker ps

# test app
http://localhost:8080

# Clean up resources
docker-compose down

# Part 2 - Azure Container Registry
# Create RG
az group create --name "aksdemo-rg" --location australiaeast

# Create ACR
az acr create --resource-group "aksdemo-rg" --name aksdemoacr01 --sku Basic

# Login to ACR - Individual Authentication
az acr login --name aksdemoacr01

# To use azure-vote-front image with ACR, the image needs to be tagged with the login server address of the registry. 
# Get the login server address
az acr list --resource-group aksdemo-rg --query "[].{acrLoginServer:loginServer}" --output table

# Tag image with ACR Login Server and add version
docker tag azure-vote-front aksdemoacr01.azurecr.io/azure-vote-front:v1

# Push image to registry
docker push <acrLoginServer>/azure-vote-front:v1

# See tags for specific image
az acr repository show-tags --name aksdemoacr01 --repository azure-vote-front --output table

# Part 3 - Create Kubernetes Cluster

# Create a service principal
az ad sp create-for-rbac --skip-assignment

# Configure ACR authentication
az acr show --resource-group aksdemo-rg --name aksdemoacr01 --query "id" --output tsv

# Grand access for AKS cluster to pull images from ACR
az role assignment create --assignee 4574df10-2fe7-48e0-82d5-a4b1b3330875 --scope /subscriptions/cc0ff371-2090-42de-84fc-c0013f955131/resourceGroups/aksdemo-rg/providers/Microsoft.ContainerRegistry/registries/aksdemoacr01 --role acrpull

# Create the Kubernetes Cluster
az aks create --resource-group aksdemo-rg --name aksdemoaks001 --node-count 1 --service-principal 4574df10-2fe7-48e0-82d5-a4b1b3330875 --client-secret f104201a-cc21-45d4-8c7f-17b6dc5c956c --generate-ssh-keys

# Connect to cluster
az aks get-credentials --resource-group aksdemo-rg --name aksdemoaks001

# Get nodes
kubectl get nodes

# Part 4 - Deploy App to AKS

# Get ACR Login Server and update manifest
az acr list --resource-group aksdemo-rg --query "[].{acrLoginServer:loginServer}" --output table

# Parses and creates the Kubernetes object
kubectl apply -f azure-vote-all-in-one-redis.yaml

# Monitor progress
kubectl get service azure-vote-front --watch

# Part 5 - Scaling your Applications

# Get Pods
kubectl get pods

# Manually Scale Pod
kubectl scale --replicas=3 deployment/azure-vote-front

# Auto scale pods
# Pre-requisites Metrics server - comes with AKS 1.10+
az aks show --resource-group aksdemo-rg --name aksdemoaks001 --query kubernetesVersion

# Autoscale pods based on cpu utilisation
kubectl autoscale deployment azure-vote-front --cpu-percent=50 --min=3 --max=10

# Manually scale AKS Nodes
az aks scale --resource-group aksdemo-rg --name aksdemoaks001 --node-count 3

# Part 6 - Updating your Applications

# Make changes to app and update the container image
docker-compose up --build -d

# Tag your image as v2
docker tag azure-vote-front aksdemoacr01.azurecr.io/azure-vote-front:v2

# Push to ACR
docker push aksdemoacr01.azurecr.io/azure-vote-front:v2

# Deploy the updated application
kubectl set image deployment azure-vote-front azure-vote-front=aksdemoacr01.azurecr.io/azure-vote-front:v2

# Test the application
kubectl get service azure-vote-front

# Part 7 - Upgrade Kubernetes
az aks get-upgrades --resource-group aksdemo-rg --name aksdemoaks001 --output table

# Upgrade the cluster
az aks upgrade --resource-group aksdemo-rg --name aksdemoaks001 --kubernetes-version 1.12.5

# Validate the upgrade
az aks show --resource-group aksdemo-rg --name aksdemoaks001 --output table


 



