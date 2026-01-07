#!/bin/bash

echo "=== Cluster Info ==="
kubectl cluster-info

echo -e "\n=== Nodes ==="
kubectl get nodes -o wide

echo -e "\n=== System Pods ==="
kubectl get pods -n kube-system

echo -e "\n=== Storage Classes ==="
kubectl get storageclass

echo -e "\n=== ArgoCD Status ==="
kubectl get pods -n argocd

echo -e "\n=== ArgoCD Services ==="
kubectl get svc -n argocd

echo -e "\n=== Ingress Controller (if installed) ==="
kubectl get pods -n ingress-nginx 2>/dev/null || echo "Not installed"

echo -e "\n=== All Namespaces ==="
kubectl get namespaces
