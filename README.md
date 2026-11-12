
# Web Service Deployment - DevOps Assessment

This repository demonstrates a complete, automated DevOps lifecycle for deploying a Node.js web application on a local K3s cluster. It encompasses containerization, Kubernetes orchestration, CI/CD automation via GitHub Actions, system health monitoring, and a comprehensive observability stack.

---

## 🏗️ Architecture Overview

The system is built on a **High-Availability (HA) K3s Cluster** running on a remote VPS. The architecture flows as follows:

1. **Development & Version Control:** Code is pushed to the `main` branch of this GitHub repository.
2. **CI/CD Pipeline (GitHub Actions):** 
   - Builds a Docker image using Docker Buildx.
   - Pushes the image to GitHub Container Registry (GHCR).
   - Authenticates with the K3s VPS via SSH.
   - Triggers a rolling update of the Kubernetes Deployment.
3. **Container Orchestration (Kubernetes):**
   - **Namespace:** All resources are isolated within the `devops-task` namespace.
   - **Workload:** A Deployment running 2 replicas of the Node.js application for high availability.
   - **Configuration:** Environment variables and secrets are managed via `ConfigMap` and `Secret`.
   - **Scaling:** Horizontal Pod Autoscaler (HPA) automatically scales replicas based on CPU usage.
4. **Traffic Routing:** An Ingress controller routes external HTTP traffic to the application's ClusterIP Service.
5. **Observability (Monitoring & Logging):**
   - **Metrics:** Prometheus scrapes application metrics via a `ServiceMonitor`.
   - **Logging:** Grafana Alloy parses JSON logs and forwards them to Loki.
   - **Visualization:** Grafana provides real-time dashboards for the Application, Host, and Containers.

---

## 🚀 Setup & Deployment Guide

### Prerequisites
- A running K3s cluster.
- `kubectl` configured with cluster access.
- GitHub Personal Access Token (PAT) with `write:packages` permission (for GHCR).

### 1. Initial Infrastructure Setup
Ensure your cluster is ready and apply the foundational configurations:
```bash
git clone [https://github.com/shuvo-halder/web-service-deploymnt.git](https://github.com/shuvo-halder/web-service-deploymnt.git)
cd web-service-deploymnt
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-config.yaml

```

### 2. Application Deployment

Apply the core application manifests. Note: The actual image tag will be managed and updated by the CI/CD pipeline.

```bash
kubectl apply -f k8s/02-deployment.yaml
kubectl apply -f k8s/03-network.yaml
kubectl apply -f k8s/04-hpa.yaml

```

### 3. Observability Setup (Step 5)

Apply the monitoring configurations to connect the application to the Prometheus Operator and Loki stack:

```bash
kubectl apply -f k8s/05-monitor.yaml
kubectl apply -f k8s/06-alloy-config.yaml
kubectl apply -f k8s/07-alerts.yaml

```

*Note: Ensure the Prometheus Operator and Grafana Alloy are pre-installed in the `monitoring` namespace.*

---

## 🤖 System Health Automation (Step 6)

A bash script (`scripts/system_health.sh`) is provided to monitor host-level metrics (CPU, Memory, Disk, Load).

**Manual Execution:**

```bash
chmod +x scripts/system_health.sh
./scripts/system_health.sh --cpu 90 --mem 85 --disk 80 --json

```

**Automated Execution (Cron):**
To run the script every 5 minutes and log the output, add the following to your server's crontab (`crontab -e`):

```bash
*/5 * * * * /root/web-service-deploymnt/scripts/system_health.sh --disk 80 --cpu 90 --mem 85 >> /var/log/health_cron_error.log 2>&1

```

---

## 🔧 Troubleshooting Guide

### Issue: Pods stuck in `ImagePullBackOff` or `ErrImagePull`

**Cause:** The K3s node cannot download the image from GHCR. This is typically due to the package visibility being set to "Private".
**Solution:**

1. Navigate to your GitHub Profile -> **Packages**.
2. Select the `web-service-deploymnt` container package.
3. Go to **Package Settings** -> **Change package visibility** and set it to **Public**.
4. Re-run the GitHub Actions workflow.

### Issue: Pods stuck in `CreateContainerConfigError`

**Cause:** The application pod is missing its required `ConfigMap` or `Secret`.
**Solution:** Ensure the configuration files are applied to the correct namespace:

```bash
kubectl apply -f k8s/01-config.yaml -n devops-task
kubectl get configmap,secret -n devops-task

```

### Issue: GitHub Actions Deployment Step Fails (Timeout)

**Cause:** The CI/CD pipeline rolled back the deployment because the pods failed the health check (`/health`) within 60 seconds.
**Solution:**

1. Check the logs of the failing pod: `kubectl logs deployment/devops-task-app -n devops-task --previous`
2. If the application is taking too long to start, increase the `initialDelaySeconds` for the `livenessProbe` and `readinessProbe` in `k8s/02-deployment.yaml`.

---

## 📊 Dashboards

JSON exports of the Grafana dashboards required for this project are located in the `/observability` directory:

* `application-dashboard.json`: Node.js specific metrics.
* `host-dashboard.json`: Node exporter metrics (CPU, RAM, Disk).
* `container-dashboard.json`: cAdvisor metrics and Loki JSON logs.

