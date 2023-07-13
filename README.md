<br/>
<br/>

<p align="center">
<img src="https://files.cloudtype.io/logo/cloudtype-logo-horizontal-black.png" width="50%" alt="Cloudtype"/>
</p>

<br/>
<br/>

# 클라우드타입 웨비나 #03<br/>클라우드타입, AWS Elastic Kubernetes Service를 활용한<br/>개발자 플랫폼 구축하기 <!-- omit in toc -->

## 목차 <!-- omit in toc -->

- [🗒️ 실습 예제 사양](#️-실습-예제-사양)
- [🖇️ 준비사항](#️-준비사항)
- [🧰 필요 도구 설치](#-필요-도구-설치)
  - [AWS CLI](#aws-cli)
  - [kubectl](#kubectl)
  - [eksctl](#eksctl)
  - [Helm](#helm)
- [🛠️ EKS 클러스터 생성하기](#️-eks-클러스터-생성하기)
  - [AWS CLI 설정](#aws-cli-설정)
  - [클러스터 생성](#클러스터-생성)
  - [키페어 생성](#키페어-생성)
  - [노드 그룹 생성](#노드-그룹-생성)
- [⚙️ EKS 클러스터 세팅하기](#️-eks-클러스터-세팅하기)
  - [Calico Network Policy Engine add-on 설치](#calico-network-policy-engine-add-on-설치)
  - [Cert Manager 설치](#cert-manager-설치)
  - [Nginx Ingress Controller 설치](#nginx-ingress-controller-설치)
  - [Cloudflare 도메인 및 인증서 적용](#cloudflare-도메인-및-인증서-적용)
  - [Kubernetes Dashboard 설치](#kubernetes-dashboard-설치)
- [📖 References](#-references)
- [💬 Contact](#-contact)

## 🗒️ 실습 예제 사양

- Kubernetes(AWS EKS)
  - Engine: v1.25
  - Node: Amazon Linux 2, t3.medium x 2
- Helm: v3.12.1
- Calico: v3.25.1
- Cert Manager: v1.12.0
- Nginx Ingress Controller: v1.8.1
- Kubernetes Dashboard: v2.7.0

## 🖇️ 준비사항

- [클라우드타입 계정](https://cloudtype.io/)
- [AWS 계정](https://aws.amazon.com/ko)
  - 루트 계정이 아닌 <u>IAM 사용자 생성 계정</u> 사용
  - 액세스키 발급
- [Cloudflare 계정](https://www.cloudflare.com/)
  - 도메인 사전 구매 필요
- [GitHub 계정](https://github.com/)

## 🧰 필요 도구 설치

### AWS CLI

- AWS CLI 설치
  - macOS

    ```bash
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
    ```

  - Windows

    ```bash
    msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
    ```

- AWS 계정 설정
  
  ```bash
  aws configure
  ```

### kubectl

- macOS

  ```bash
  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.9/2023-05-11/bin/darwin/amd64/kubectl
  ```

- Windows(PowerShell)

  ```bash
  curl.exe -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.9/2023-05-11/bin/windows/amd64/kubectl.exe
  ```

### eksctl

- macOS

  ```bash
  brew tap weaveworks/tap
  brew install weaveworks/tap/eksctl
  eksctl version
  ```

- Windows
  - [다운로드 링크](https://eksctl.io/introduction/#for-windows)

### Helm

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

## 🛠️ EKS 클러스터 생성하기

### AWS CLI 설정

### 클러스터 생성

```bash
$ eksctl create cluster --name=[클러스터명] \
                      --region=[리전] \
                      --without-nodegroup 
```

### 키페어 생성

1. **EC2 > Network & Security > Key Pairs** 메뉴로 진입합니다.
2. **Create key pair** 버튼을 누르고 다음의 항목을 확인하고 키를 생성합니다.
   - Name: 키페어명
   - Key pair type: RSA
   - Private key file format: .pem
3. 키페어 생성이 정상적으로 완료되면 `.pem` 확장자의 파일이 다운로드 됩니다. 보안에 유의하여 안전한 위치에 파일을 보관합니다. 

### 노드 그룹 생성

```bash
$ eksctl create nodegroup --cluster=[클러스터명] \
                       --region=[리전] \
                       --name=[노드그룹명] \
                       --node-type=t3.medium \        # 인스턴스 유형 
                       --nodes=2 \                    # 노드 수
                       --nodes-min=2 \                # 노드 수 하한
                       --nodes-max=4 \                # 노드 수 상한
                       --node-volume-size=20 \        # 노드 볼륨 크기
                       --ssh-access \
                       --ssh-public-key=[키파일명] \  # SSH(*.pem) 퍼블릭 키
                       --managed \
                       --asg-access \
                       --external-dns-access \
                       --full-ecr-access \
                       --appmesh-access \
                       --alb-ingress-access 
```

## ⚙️ EKS 클러스터 세팅하기

### Calico Network Policy Engine add-on 설치

- Calico 설치

  ```bash
  $ helm repo add projectcalico https://docs.tigera.io/calico/charts
  $ helm repo update
  $ echo '{ installation: {kubernetesProvider: EKS }}' > values.yaml
  $ kubectl create namespace tigera-operator
  $ helm install calico projectcalico/tigera-operator --version v3.25.1 -f values.yaml --namespace tigera-operator
  ```

- Network Policy Engine add-on 적용

  ```bash
  $ cat << EOF > append.yaml
  - apiGroups:
    - ""
    resources:
    - pods
    verbs:
    - patch
  EOF

  $ kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append.yaml)
  $ kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true
  $ kubectl delete pod calico-kube-controllers-[pod 이름 확인] -n calico-system
  ```

### Cert Manager 설치

```bash
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo update
$ helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.12.0 \
  --set installCRDs=true
```

### Nginx Ingress Controller 설치

```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

### Cloudflare 도메인 및 인증서 적용

  1. Cloudflare API KEY 발급
  2. `ingress-nginx-controller` LoadBalancer 외부 IP CNAME 레코드 등록
  3. Cloudflare API KEY 환경변수 등록
      ```bash
        export CLOUDFLARE_ACME_EMAIL=<Cloudflare 계정 ID>
        export CLOUDFLARE_API_TOKEN=<Cloudflare API KEY>
      ```
  4. Cluster Issuer / Certificate 생성

      ```bash
      $ cat <<EOF | kubectl apply -f -
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
        api-token: "${CLOUDFLARE_API_TOKEN}""
      ---
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: cloudtype-crt
        namespace: cert-manager
      spec:
        acme:
          email: "${CLOUDFLARE_ACME_EMAIL}"
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
                  - [Cloudflare에 등록된 도메인]
      ---
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: cloudtype-app-tls
        namespace: cloudtype-commons
      spec:
        dnsNames:
          - "[Cloudflare에 등록된 도메인]"
          - "*.[Cloudflare에 등록된 도메인]"
        issuerRef:
          kind: ClusterIssuer
          name: cloudtype-crt
        secretName: cloudtype-app-tls
      EOF
      ```

### Kubernetes Dashboard 설치

- Kubernetes Dashboard 설치

  ```bash
  $ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
  ```

- Admin 권한 Service Account / ClusterRoleBinding 생성

  ```bash
  $ cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: admin-user
    namespace: kubernetes-dashboard
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: admin-user
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
  subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
  EOF
  ```

- Secret 생성

  ```bash
  $ cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: Secret
  metadata:
    namespace: kubernetes-dashboard
    name: admin-user-token
    annotations:
      kubernetes.io/service-account.name: admin-user
  type: kubernetes.io/service-account-token
  EOF
  ```

- Service Account에 Secret 마운트
  
  ```bash
  $ cat <<EOF | kubectl patch serviceaccount admin-user --type=merge --patch '{
  "secrets":
    {
      "name": "admin-user-token"
    }
  }'
  EOF
  ```

## 📖 References

- [클라우드타입 Docs](https://docs.cloudtype.io/)
- [클라우드타입 FAQ](https://help.cloudtype.io/guide/faq)
- [AWS Elastic Kubernetes Service](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/getting-started.html)
- [AWS Command Line Interface](https://aws.amazon.com/ko/cli/)
- [eksctl](https://eksctl.io/)

## 💬 Contact

- [Discord](https://discord.gg/U7HX4BA6hu)
