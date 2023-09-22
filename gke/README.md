<br/>
<br/>

<p align="center">
<img src="https://files.cloudtype.io/logo/cloudtype-logo-horizontal-black.png" width="50%" alt="Cloudtype"/>
</p>

<br/>
<br/>

# 클라우드타입과 Google Kubernetes Engine를 활용한<br/>개발자 플랫폼 구축하기 <!-- omit in toc -->

## 목차 <!-- omit in toc -->

- [🗒️ 실습 예제 사양](#️-실습-예제-사양)
- [🖇️ 준비사항](#️-준비사항)
- [🧰 필요 도구 설치](#-필요-도구-설치)
  - [gcloud CLI](#gcloud-cli)
  - [kubectl](#kubectl)
  - [Helm](#helm)
- [🛠️ GKE 클러스터 생성하기](#️-gke-클러스터-생성하기)
  - [클러스터 생성](#클러스터-생성)
- [⚙️ GKE 클러스터 세팅하기](#️-gke-클러스터-세팅하기)
  - [Cert Manager 설치](#cert-manager-설치)
  - [Nginx Ingress Controller 설치](#nginx-ingress-controller-설치)
  - [Cloudflare 도메인 및 인증서 적용](#cloudflare-도메인-및-인증서-적용)
  - [Compute Engine Persistent Disk CSI 테스트](#compute-engine-persistent-disk-csi-테스트)
- [☁️ 클라우드타입 연동하기](#️-클라우드타입-연동하기)
  - [클라우드타입 에이전트 설치 및 클러스터 추가](#클라우드타입-에이전트-설치-및-클러스터-추가)
  - [컨테이너 레지스트리 연결](#컨테이너-레지스트리-연결)
  - [클러스터 네트워크 설정](#클러스터-네트워크-설정)
  - [클러스터 스토리지 설정](#클러스터-스토리지-설정)
- [📖 References](#-references)
- [💬 Contact](#-contact)

## 🗒️ 실습 예제 사양

- Kubernetes(GCP GKE)
  - Engine: 1.25.12-gke.500
  - Node: ubuntu_containerd, e2-standard-2 x 3
- Helm: v3.12.1
- Cert Manager: v1.12.0
- Nginx Ingress Controller: v1.8.1

## 🖇️ 준비사항

- [클라우드타입 계정](https://cloudtype.io/)
- [GCP 계정](https://cloud.google.com/)
- [Cloudflare 계정](https://www.cloudflare.com/)
  - 도메인 사전 구매 필요
- [GitHub 계정](https://github.com/)

## 🧰 필요 도구 설치

### gcloud CLI

- gcloud CLI 설치

    https://cloud.google.com/sdk/docs/install?hl=ko

- gcloud 계정 설정
  
  ```bash
  $ gcloud init
  ```

- 인증 플러그인 설치

  ```bash
  $ gcloud components install gke-gcloud-auth-plugin
  ```

### kubectl

  ```bash
  $ gcloud components install kubectl
  ```

### Helm

```bash
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```

## 🛠️ GKE 클러스터 생성하기

### 클러스터 생성

1. 클러스터 만들기 팝업에서 **Standard: 사용자가 클러스터 관리**의 구성 버튼을 클릭합니다.

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-01.png" width="70%" alt="Cloudtype"/>
    </p>

2. 클러스터 기본사항

    - 클러스터 이름과 위치 유형은 각 상황에 맞게 적절히 선택
    - 제어 영역 버전
      - 정적 버전: 1.25.12-gke.500

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-02.png" width="70%" alt="Cloudtype"/>
    </p>

3. 노드 풀 세부정보

    - 최초 설정에서 변경 없음

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-03.png" width="70%" alt="Cloudtype"/>
    </p>

4. 노드

    - 이미지 유형: containerd를 포함한 Ubuntu(ubuntu_containerd)
    - 머신 유형: e2-standard-2  

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-04.png" width="70%" alt="Cloudtype"/>
    </p>

5. 자동화

    - **수직형 포드 자동 확장 사용 설정** 체크

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-05.png" width="70%" alt="Cloudtype"/>
    </p>

6. 네트워킹

    - **Calico Kubernetes 네트워크 정책 사용 설정** 체크
    - **L4 내부 부하 분산기용 하위 설정 사용** 체크

    <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-06.png" width="70%" alt="Cloudtype"/>
    </p>

## ⚙️ GKE 클러스터 세팅하기

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
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
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
  
  2. `ingress-nginx-controller` LoadBalancer 외부 IP A 레코드 등록
     - `ingress-nginx-controller` LoadBalancer 외부 IP(Hostname) 확인

        ```bash
        $ kubectl get svc \
            -n ingress-nginx \
            ingress-nginx-controller \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
        ```

     - Cloudflare에서 연동할 도메인의 대시보드에서, **DNS > 레코드** 페이지 이동
     - 레코드 추가 버튼 클릭 후, 다음 두 개의 레코드 추가
        <p align="center">
        <img src="https://files.cloudtype.io/webinar/webinar-03-02.png" width="90%" alt="Cloudtype"/>
        </p>

       - 유형: A, 이름: *, IPv4 주소: 위에서 조회한 LoadBalancer 외부 IP
       - 유형: A, 이름: 현재 도메인(example.com인 경우 example.com), IPv4 주소: 위에서 조회한 LoadBalancer 외부 IP

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
        name: cloudtype
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
        name: cloudtype-tls
        namespace: cloudtype
      spec:
        dnsNames:
          - "[Cloudflare에 등록된 도메인]"
          - "*.[Cloudflare에 등록된 도메인]"
        issuerRef:
          kind: ClusterIssuer
          name: cloudtype-crt
        secretName: cloudtype-tls
      EOF
      ```

  5. Cert Manager Order 상태 확인

      ```bash
      $ kubectl get order -n cloudtype \
        | awk '/cloudtype-tls-/{print $1}' \
        | xargs kubectl get order -n cloudtype
      ```

     - 정상적으로 TLS 인증서를 발급할 수 있는 상태인지 확인 필요
       - Order의 **STATE** 항목 값이 **valid**여야 클라우드타입에서 배포한 서비스에 대하여 HTTPS 인증이 정상적으로 진행
     - Cloudflare DNS의 도메인에 인증서가 발급되기 위한 상태가 되기까지 약 30분~1시간 소요

### Compute Engine Persistent Disk CSI 테스트

  1. PVC 생성 테스트

      ```bash
      $ cat <<EOF | kubectl apply -f -
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: pvc-test
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: standard
        resources:
          requests:
            storage: 1Gi
      EOF
      ```

  2. PVC 상태 확인

      ```bash
      $ kubectl get pvc pvc-test
      ```

      - PVC의 **STATUS**가 **Bound**인지 확인

## ☁️ 클라우드타입 연동하기

### 클라우드타입 에이전트 설치 및 클러스터 추가

  1. 에이전트 설치

      ```bash
      $ kubectl apply -f https://raw.githubusercontent.com/cloudtype/agent/master/k8s/v1.0.0/agent.yaml
      ```

  2. GKE 클러스터 에이전트 접속 주소 확인

      ```bash
      $ kubectl get svc \
            -n cloudtype \
            agent \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' \
        | xargs -I{} echo "https://{}"
      ```

  3. 에이전트 토큰 값 조회

      ```bash
      $ kubectl get secrets agent-secret -n cloudtype -o jsonpath='{.data.agent-token}' | base64 --decode
      ```

  4. 클라우드타입에서 클러스터 연결
      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-07.png" width="60%" alt="Cloudtype"/>
      </p>

### 컨테이너 레지스트리 연결

  1. 레지스트리 생성
      - GCP ECR 콘솔에서 **저장소 만들기** 버튼 누른 후 저장소명 작성, 형식에서 **Docker** 선택, 리전 선택 후 만들기 버튼 클릭
      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-08.png" width="70%" alt="Cloudtype"/>
      </p>

  2. 레지스트리 주소 확인
      - `리전-docker.pkg.dev/프로젝트명/저장소명`
      - 예) asia-northeast3-docker.pkg.dev/myproject/myregistry

  3. 레지스트리 접근 서비스 계정 생성
      - 서비스 계정 이름은 적절히 작성
      - 역할 선택 항목에서 **Artifact Registry 관리자** 선택
      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-09.png" width="60%" alt="Cloudtype"/>
      </p>

  4. 서비스 계정 키 생성
      - 생성한 서비스 계정의 우측 설정 버튼 클릭 후 키 관리 클릭

      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-10.png" width="60%" alt="Cloudtype"/>
      </p>

      - 키 관리 콘솔에서 키 추가 - 새 키 만들기 버튼 클릭

      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-11.png" width="60%" alt="Cloudtype"/>
      </p>

      - 키 종류는 JSON 선택하고 만들기 버튼을 누르면 키 파일이 다운로드됨

      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-12.png" width="60%" alt="Cloudtype"/>
      </p>

  5. 클러스터 레지스트리 설정
   
      - 접속 주소는 2번, 키파일은 4번을 참조하여 값 입력

      <p align="center">
        <img src="https://files.cloudtype.io/guides/gke-13.png" width="60%" alt="Cloudtype"/>
      </p>

### 클러스터 네트워크 설정

  1. 인증서 시크릿 이름
      - cloudtype-tls
  2. 인증서 시크릿 네임스페이스
      - cloudtype
  3. 인증서 발급기
      - cloudtype-crt
  4. 기본 도메인
      - 이전 단계에서 Nginx Ingress Controller 세팅 시 사용했던 Cloudflare 도메인
  5. 인그레스 정보
      - 인그레스 클래스: nginx
      - 인그레스 IP: Nginx Ingress Controller LoadBalancer 외부 IP/Hostname
  6. 로드밸런서 유형
      - LoadBalancer

  <p align="center">
    <img src="https://files.cloudtype.io/webinar/webinar-03-09.png" width="65%" alt="Cloudtype"/>
  </p>

### 클러스터 스토리지 설정

  1. 스토리지 클래스
     - standard
     - 입력하지 않으면 클러스터의 default 스토리지 클래스 사용
  2. 볼륨 모드
     - RWO

  <p align="center">
    <img src="https://files.cloudtype.io/guides/gke-14.png" width="65%" alt="Cloudtype"/>
  </p>

## 📖 References

- [클라우드타입 Docs](https://docs.cloudtype.io/)
- [클라우드타입 FAQ](https://help.cloudtype.io/guide/faq)

## 💬 Contact

- [Discord](https://discord.gg/U7HX4BA6hu)
