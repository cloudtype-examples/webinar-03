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
  - [AWS EBS CSI 설치](#aws-ebs-csi-설치)
- [☁️ 클라우드타입 연동하기](#️-클라우드타입-연동하기)
  - [클라우드타입 에이전트 설치 및 클러스터 추가](#클라우드타입-에이전트-설치-및-클러스터-추가)
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

    ```bash
    $ curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    $ sudo installer -pkg AWSCLIV2.pkg -target /
    ```

- AWS 계정 설정
  
  ```bash
  $ aws configure
  ```

### kubectl

  ```bash
  $ curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.25.9/2023-05-11/bin/darwin/amd64/kubectl
  ```

### eksctl

- macOS

  ```bash
  $ brew tap weaveworks/tap
  $ brew install weaveworks/tap/eksctl
  $ eksctl version
  ```

- Windows
  - [다운로드 링크](https://eksctl.io/introduction/#for-windows)

### Helm

```bash
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```

## 🛠️ EKS 클러스터 생성하기

### AWS CLI 설정

### 클러스터 생성

```bash
$ eksctl create cluster \
          --name=[클러스터명] \
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
$ eksctl create nodegroup \
                    --cluster=[클러스터명] \
                    --region=[리전] \
                    --name=[노드그룹명] \
                    --node-type=t3.medium \      
                    --nodes=2 \                
                    --nodes-min=2 \              
                    --nodes-max=4 \               
                    --node-volume-size=20 \       
                    --ssh-access \
                    --ssh-public-key=[키파일명] \  
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
  $ helm install calico projectcalico/tigera-operator \
          --version v3.25.1 \
          --set installation.kubernetesProvider=EKS \
          --namespace tigera-operator \
          --create-namespace
  $ helm -n tigera-operator get values calico
  ```

- Network Policy Engine add-on 적용

  ```bash
  $ kubectl patch clusterrole aws-node \
            --type='json' \
            -p='[{"op": "add", "path": "/rules/-1", "value":{ "apiGroups": [""], "resources": ["pods"], "verbs": ["patch"]}}]' \
            -o yaml
  $ kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true
  $ kubectl get po -n calico-system | grep calico-kube-controllers-                   # pod 이름은 난수 형태로 할당되어 개별적으로 확인 필요
  $ kubectl delete pod calico-kube-controllers-[조회한 pod 이름] -n calico-system     # 위 명령어에서 확인된 pod 이름 입력하여 삭제
  $ kubectl get po -n calico-system | grep calico-kube-controllers-                   # 삭제 후 재생성된 pod 정상 상태 확인
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
     - Cloudflare **내 프로필 > API 토큰** 페이지 이동
     - **토큰 생성** 버튼 클릭
     - **영역 DNS 편집** 템플릿 사용 버튼 클릭
     - 다음 이미지와 같이 세팅 후, 요약 계속 버튼 클릭(영역 리소스 항목은 사용할 도메인 선택)
        <p align="center">
        <img src="https://files.cloudtype.io/webinar/webinar-03-01.png" width="80%" alt="Cloudtype"/>
        </p>
     - 클라우드타입과 연동할 도메인 확인 후, 토큰 생성 버튼 클릭
  2. `ingress-nginx-controller` LoadBalancer 외부 IP CNAME 레코드 등록
     - `ingress-nginx-controller` LoadBalancer 외부 IP(Hostname) 확인
        ```bash
        $ kubectl get svc \
            -n ingress-nginx \
            ingress-nginx-controller \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'  # EKS의 경우 LoadBalancer의 외부 IP를 URL 형식으로 할당
        ```
     - Cloudflare에서 연동할 도메인의 대시보드에서, **DNS > 레코드** 페이지 이동
     - 레코드 추가 버튼 클릭 후, 다음 두 개의 레코드 추가
        <p align="center">
        <img src="https://files.cloudtype.io/webinar/webinar-03-02.png" width="90%" alt="Cloudtype"/>
        </p>

       - 유형: CNAME, 이름: *, IPv4 주소: 위에서 조회한 LoadBalancer 외부 IP
       - 유형: CNAME, 이름: 현재 도메인(example.com인 경우 example.com), IPv4 주소: 위에서 조회한 LoadBalancer 외부 IP
  3. Cloudflare API KEY 환경변수 등록

      ```bash
      $ export CLOUDFLARE_ACME_EMAIL=<Cloudflare 계정 ID>
      $ export CLOUDFLARE_API_TOKEN=<Cloudflare API KEY>
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
        api-token: "${CLOUDFLARE_API_TOKEN}"
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

### AWS EBS CSI 설치

  1. 클러스터 IAM OIDC 제공업체 생성

      ```bash
      $ export CLUSTER_NAME=cloudtype-test
      $ OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
      $ aws iam list-open-id-connect-providers | grep $OIDC_ID | cut -d "/" -f4
      $ eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve
      ```

  2. EBS CSI 드라이버 IAM 역할 생성

      ```bash
      $ eksctl create iamserviceaccount \
          --name ebs-csi-controller-sa \
          --namespace kube-system \
          --cluster cloudtype-test \
          --role-name AmazonEKS_EBS_CSI_DriverRole \
          --role-only \
          --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
          --approve
      ```

  3. EKS add-on EBS CSI 드라이버 적용

      ```bash
      $ export ACCOUNT_ID=[Account ID]
      $ eksctl create addon \
          --name aws-ebs-csi-driver \
          --cluster ${CLUSTER_NAME} \
          --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole \
          --force
      ```

  4. Storage Class 적용

      ```bash
      $ cat <<EOF | kubectl apply -f -
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: gp3
        annotations:
          storageclass.kubernetes.io/is-default-class: "true"
      allowVolumeExpansion: true
      provisioner: ebs.csi.aws.com
      volumeBindingMode: Immediate
      parameters:
        type: gp3
        allowAutoIOPSPerGBIncrease: 'true'
        encrypted: 'true'
      EOF
      ```

  5. PVC 생성 테스트

      ```bash
      $ cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: pvc-test
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: gp3
        resources:
          requests:
            storage: 1Gi
      EOF
      ```

## ☁️ 클라우드타입 연동하기

### 클라우드타입 에이전트 설치 및 클러스터 추가

  1. 에이전트 설치

      ```bash
      $ kubectl apply -f https://raw.githubusercontent.com/cloudtype/agent/master/k8s/agent.yaml
      ```

  2. AWS ECR 토큰 값 조회

      ```bash
      $ aws ecr get-login-password --region [리전 ex.ap-northeast-2]
      ```

  3. 에이전트 토큰 값 조회

      ```bash
      $ kubectl get secrets agent-secret -n cloudtype -o jsonpath='{.data.agent-token}' | base64 --decode
      ```

  4. EKS 클러스터 API 엔드포인트 확인
      <p align="center">
        <img src="https://files.cloudtype.io/webinar/webinar-03-03.png" width="80%" alt="Cloudtype"/>
      </p>

  5. 클라우드타입에서 클러스터 연결
      <p align="center">
        <img src="https://files.cloudtype.io/webinar/webinar-03-04.png" width="60%" alt="Cloudtype"/>
      </p>

## 📖 References

- [클라우드타입 Docs](https://docs.cloudtype.io/)
- [클라우드타입 FAQ](https://help.cloudtype.io/guide/faq)
- [AWS Elastic Kubernetes Service](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/getting-started.html)
- [AWS Command Line Interface](https://aws.amazon.com/ko/cli/)
- [eksctl](https://eksctl.io/)

## 💬 Contact

- [Discord](https://discord.gg/U7HX4BA6hu)
