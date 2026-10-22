# Experiment 7: Deploying Applications, CI/CD Pipeline, and Cluster Monitoring

A static nginx web app that is built and pushed to Docker Hub by GitHub Actions, deployed and scaled
on Minikube, and monitored with Metrics Server / Minikube Dashboard or Prometheus + Grafana.

## Repository layout

```
sample-web-app/
├── .github/workflows/ci-cd.yml   # CI/CD: build + push image to Docker Hub on every push to main
├── Dockerfile                    # nginx:alpine serving index.html
├── index.html                    # the web page
├── deployment.yaml               # Kubernetes Deployment (2 replicas, CPU/memory requests & limits)
├── service.yaml                  # optional NodePort Service to open the app in a browser
└── .dockerignore
```

## 0. Prerequisites (one time)

Docker Desktop running, plus `kubectl`, `minikube`, `helm` and `git` installed.

```powershell
winget install Kubernetes.kubectl
winget install Kubernetes.minikube
winget install Helm.Helm
minikube start --driver=docker
kubectl get nodes          # should show "minikube   Ready"
```

## Activity 1: Deploy and scale (CO3)

```powershell
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get pods -l app=web               # 2 pods Running

kubectl scale deployment sample-web-app --replicas=5
kubectl get pods -w                       # watch 3 new pods appear; Ctrl+C to stop
kubectl get pods -l app=web               # SCREENSHOT 1: 5 pods Running
```

Optional, to view the app in a browser:

```powershell
kubectl apply -f service.yaml
minikube service sample-web-app-svc
```

## Activity 2: CI/CD with GitHub Actions (CO5)

1. Docker Hub → Account Settings → Personal access tokens → Generate (Read & Write). Copy the token.
2. Create an empty public GitHub repo named `sample-web-app`.
3. In the repo: Settings → Secrets and variables → Actions → New repository secret:
   - `DOCKERHUB_USERNAME` = your Docker Hub username
   - `DOCKERHUB_TOKEN` = the token from step 1
4. Push this folder:

```powershell
git init
git add .
git commit -m "feat: configure GitHub Actions CI/CD pipeline"
git branch -M main
git remote add origin https://github.com/<your-github-username>/sample-web-app.git
git push -u origin main
```

5. Open the repo's **Actions** tab and wait for the green check. **SCREENSHOT 2.**
6. Confirm `sample-web-app` with tags `v1.0.1` and `latest` appears on Docker Hub.

Deploy your own pipeline-built image instead of plain nginx (optional, shows the full loop):

```powershell
kubectl set image deployment/sample-web-app web-container=<dockerhub-username>/sample-web-app:v1.0.1
kubectl rollout status deployment/sample-web-app
```

## Activity 3: Monitoring (CO6)

### Option A: Metrics Server + Minikube Dashboard (lighter, recommended for laptops)

```powershell
minikube addons enable metrics-server
# wait ~60 seconds
kubectl top nodes
kubectl top pods
minikube dashboard        # opens browser; Workloads → Pods shows CPU/memory graphs
```

**SCREENSHOT 3:** the CPU/memory graphs in the dashboard (graphs appear after a minute or two of data).

### Option B: Prometheus + Grafana (needs ~4 GB free RAM for Minikube)

```powershell
minikube stop
minikube start --driver=docker --memory=4096 --cpus=2

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack
kubectl get pods -w                       # wait until monitoring-* pods are Running

# Newer chart versions generate a random admin password, so read it from the secret:
kubectl get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | `
  ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }

kubectl port-forward svc/monitoring-grafana 3000:80
```

Open http://localhost:3000 and log in as `admin` (password from the command above; older charts
use `prom-operator`). Go to Dashboards → **Kubernetes / Compute Resources / Namespace (Pods)**,
pick namespace `default`, and capture the CPU/memory graphs for the `sample-web-app` pods.

## Troubleshooting

| Problem | Fix |
|---|---|
| `ErrImagePull` / `ImagePullBackOff` | Check the image name/tag; make the Docker Hub repo public. |
| Actions fails at "Log in to Docker Hub" | Secret names must be exactly `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`; token needs Read & Write. |
| Actions fails at build: "denied: requested access" | The token is read-only, or the username secret has a typo. |
| `kubectl top pods`: metrics not available | `minikube addons enable metrics-server`, then wait 60 s. |
| Minikube won't start | Open Docker Desktop first and wait until it shows "Engine running". |
| Grafana pods stuck `Pending` | Not enough memory; restart Minikube with `--memory=4096` or use Option A. |

## Clean up

```powershell
helm uninstall monitoring
kubectl delete -f service.yaml -f deployment.yaml
minikube stop
```
