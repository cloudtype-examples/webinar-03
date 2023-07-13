#!/bin/bash

# if [ -z "$PREFIX" ]; then echo "Need to set PREFIX"; exit 1; fi
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then echo "Need to set CLOUDFLARE_API_TOKEN"; exit 1; fi
if [ -z "$CLOUDFLARE_ACME_EMAIL" ]; then echo "Need to set CLOUDFLARE_ACME_EMAIL"; exit 1; fi

set -ex

# setup cloudtype-commons namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: cloudtype-commons
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: ${CLOUDFLARE_API_TOKEN}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudtype-crt
  namespace: cert-manager
spec:
  acme:
    email: ${CLOUDFLARE_ACME_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudtype-crt
    solvers:
      - http01:
          ingress:
            class: nginx
      - dns01:
          cloudflare:
            email: "${CLOUDFLARE_ACME_EMAIL}"
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
        selector:
          dnsZones:
            - example.com
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cloudtype-app-tls
  namespace: cloudtype-commons
spec:
  dnsNames:
    - "example.com"
    - "*.example.com"
  issuerRef:
    kind: ClusterIssuer
    name: cloudtype-crt
  secretName: cloudtype-app-tls
EOF
