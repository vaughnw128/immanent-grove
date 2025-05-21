# Set up FluxCD

I have Flux set up with all of the extra components

```bash
flux bootstrap github \
  --token-auth \
  --owner=vaughnw128 \
  --repository=immanent-grove \
  --branch=main \
  --path=cluster \
  --personal \
--components source-controller,kustomize-controller,helm-controller,notification-controller \
--components-extra image-reflector-controller,image-automation-controller
```
