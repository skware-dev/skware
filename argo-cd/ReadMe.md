
# ArgoCD App

The ArgoCD application allowing ArgoCD to manage itself.

```bash
kubectl apply -f https://github.com/skware-dev/skware/raw/main/argo-cd/argocd-app.yaml
```

Uses kustomize to apply the [Apps health assessment](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#argocd-app) patch in order to use sync-waves of Apps.



