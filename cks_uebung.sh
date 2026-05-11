#!/bin/bash
# CKS 2026 - Setup/Teardown Script für eigene Übungsaufgaben
#
# Usage:
#   ./cks_uebung.sh setup u11      # Bereitet Ü1.1 vor
#   ./cks_uebung.sh teardown u11   # Räumt Ü1.1 weg
#   ./cks_uebung.sh list           # Zeigt alle verfügbaren Aufgaben
#   ./cks_uebung.sh setup-all      # Bereitet ALLES vor (Vorsicht!)
#   ./cks_uebung.sh teardown-all   # Räumt ALLES weg

set -e

# =============================================================
# HILFSFUNKTIONEN
# =============================================================

ns_create() {
    kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f -
}

ns_delete() {
    kubectl delete namespace "$1" --ignore-not-found --wait=false 2>/dev/null || true
}

log() {
    echo ">>> $*"
}

# =============================================================
# 1. CLUSTER SETUP
# =============================================================

# -------- Ü1.1: NetworkPolicy 3-Tier --------
setup_u11() {
    log "Setup Ü1.1: Frontend-Backend-Database 3-Tier"
    ns_create webshop

    # Frontend Pods (3 Stück)
    for i in 1 2 3; do
        kubectl run frontend-$i --image=nginxinc/nginx-unprivileged:1.25 \
            --labels=tier=frontend -n webshop 2>/dev/null || true
    done

    # Backend Pods (2 Stück)
    for i in 1 2; do
        kubectl run backend-$i --image=nginxinc/nginx-unprivileged:1.25 \
            --labels=tier=backend -n webshop 2>/dev/null || true
    done

    # Database Pod
    kubectl run database-1 --image=nginxinc/nginx-unprivileged:1.25 \
        --labels=tier=database -n webshop 2>/dev/null || true

    log "Setup Ü1.1 fertig - Pods in 'webshop' deployed"
}

teardown_u11() {
    log "Teardown Ü1.1"
    ns_delete webshop
}

# -------- Ü1.2: kube-bench --------
setup_u12() {
    log "Setup Ü1.2: kube-bench"
    mkdir -p /opt/compliance
    # Sicherstellen dass kube-bench installiert ist
    if ! command -v kube-bench &> /dev/null; then
        log "WARNUNG: kube-bench nicht installiert. Bitte manuell installieren:"
        log "  curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz"
    fi
    log "Setup Ü1.2 fertig"
}

teardown_u12() {
    log "Teardown Ü1.2"
    rm -rf /opt/compliance
}

# -------- Ü1.3: Ingress TLS --------
setup_u13() {
    log "Setup Ü1.3: Ingress TLS (nur Verzeichnis vorbereiten)"
    mkdir -p /opt/certs
    log "Setup Ü1.3 fertig - User soll Cert, Pod, Service, Ingress selbst erstellen"
}

teardown_u13() {
    log "Teardown Ü1.3"
    ns_delete api-gateway
    rm -rf /opt/certs
}

# -------- Ü1.4: Cloud Metadata blockieren --------
setup_u14() {
    log "Setup Ü1.4: Cloud Metadata Block"
    ns_create app-runtime
    log "Setup Ü1.4 fertig"
}

teardown_u14() {
    log "Teardown Ü1.4"
    ns_delete app-runtime
}

# -------- Ü1.5: kubeadm Binary Verification --------
setup_u15() {
    log "Setup Ü1.5: Binary Verification"
    mkdir -p /opt/upgrade
    log "Setup Ü1.5 fertig"
}

teardown_u15() {
    log "Teardown Ü1.5"
    rm -rf /opt/upgrade
    sudo rm -f /usr/local/bin/kubeadm-new 2>/dev/null || true
}

# =============================================================
# 2. CLUSTER HARDENING
# =============================================================

# -------- Ü2.1: RBAC CI-Bot --------
setup_u21() {
    log "Setup Ü2.1: RBAC CI-Bot"
    mkdir -p /opt/audit
    ns_create staging
    log "Setup Ü2.1 fertig"
}

teardown_u21() {
    log "Teardown Ü2.1"
    ns_delete staging
    rm -rf /opt/audit
}

# -------- Ü2.2: Default-SA Token off --------
setup_u22() {
    log "Setup Ü2.2: Monitoring Namespace mit 3 Deployments"
    mkdir -p /opt/sa-check
    ns_create monitoring

    # 3 Deployments mit default SA (kein automountServiceAccountToken-Setting)
    for app in prometheus grafana alertmanager; do
        cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
      - name: app
        image: nginxinc/nginx-unprivileged:1.25
YAML
    done

    log "Setup Ü2.2 fertig - Default-SA hat noch Auto-Mount"
}

teardown_u22() {
    log "Teardown Ü2.2"
    ns_delete monitoring
    rm -rf /opt/sa-check
}

# -------- Ü2.3: API Server anonyme Auth --------
setup_u23() {
    log "Setup Ü2.3: API Server Hardening"
    mkdir -p /opt/hardening
    log "WARNUNG: Diese Aufgabe modifiziert /etc/kubernetes/manifests/kube-apiserver.yaml"
    log "Falls etwas schief geht: sudo cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml"
    log "Setup Ü2.3 fertig"
}

teardown_u23() {
    log "Teardown Ü2.3"
    rm -rf /opt/hardening
    # Backup zurückspielen falls existiert
    if [ -f /root/kube-apiserver.yaml.bak ]; then
        log "Backup wird zurückgespielt..."
        sudo cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
        sudo rm /root/kube-apiserver.yaml.bak
    fi
}

# -------- Ü2.4: Worker Node Upgrade --------
setup_u24() {
    log "Setup Ü2.4: Worker Node Upgrade"
    mkdir -p /opt/upgrade
    log "WARNUNG: Diese Aufgabe modifiziert Worker-Node-Komponenten"
    log "Setup Ü2.4 fertig"
}

teardown_u24() {
    log "Teardown Ü2.4"
    rm -rf /opt/upgrade
}

# =============================================================
# 3. SYSTEM HARDENING
# =============================================================

# -------- Ü3.1: AppArmor Custom Profile --------
setup_u31() {
    log "Setup Ü3.1: AppArmor"
    ns_create restricted-net
    log "Setup Ü3.1 fertig - User soll Profil-Datei + Pod erstellen"
}

teardown_u31() {
    log "Teardown Ü3.1"
    ns_delete restricted-net
    # AppArmor-Profil entladen falls geladen
    sudo apparmor_parser -R /etc/apparmor.d/app-net-restrict 2>/dev/null || true
    sudo rm -f /etc/apparmor.d/app-net-restrict
}

# -------- Ü3.2: Seccomp RuntimeDefault via PSS --------
setup_u32() {
    log "Setup Ü3.2: PSS restricted Namespace"
    mkdir -p /opt/pss
    ns_create secure-apps
    log "Setup Ü3.2 fertig"
}

teardown_u32() {
    log "Teardown Ü3.2"
    ns_delete secure-apps
    rm -rf /opt/pss
}

# -------- Ü3.3: Verdächtige Pakete --------
setup_u33() {
    log "Setup Ü3.3: Verdächtige Linux-Pakete installieren (für realistischen Test)"
    mkdir -p /opt/audit

    # Mindestens ein paar installieren, damit's was zu finden gibt
    sudo apt-get update -qq
    sudo apt-get install -y -qq nmap tcpdump netcat-openbsd 2>/dev/null || \
        log "WARNUNG: Konnte Test-Pakete nicht installieren"

    log "Setup Ü3.3 fertig - Pakete sind installiert, sollen gefunden + entfernt werden"
}

teardown_u33() {
    log "Teardown Ü3.3"
    rm -rf /opt/audit
    # Pakete bleiben weg (sollten durch die Aufgabe entfernt sein)
}

# =============================================================
# 4. MINIMIZE MICROSERVICE VULNERABILITIES
# =============================================================

# -------- Ü4.1: PSS baseline --------
setup_u41() {
    log "Setup Ü4.1: PSS baseline Namespace"
    mkdir -p /opt/pss-test
    log "Setup Ü4.1 fertig - Namespace soll vom User mit Labels erstellt werden"
}

teardown_u41() {
    log "Teardown Ü4.1"
    ns_delete mid-trust
    rm -rf /opt/pss-test
}

# -------- Ü4.2: etcd Encryption Verify --------
setup_u42() {
    log "Setup Ü4.2: Encryption-at-Rest Verifikation"
    mkdir -p /opt/verify
    log "VORAUSSETZUNG: kube-apiserver muss --encryption-provider-config gesetzt haben"
    log "Falls nicht: Aufgabe testet nicht korrekt - Encryption muss vorher konfiguriert sein"
    log "Setup Ü4.2 fertig"
}

teardown_u42() {
    log "Teardown Ü4.2"
    ns_delete secure-vault
    rm -rf /opt/verify
}

# -------- Ü4.3: gVisor RuntimeClass --------
setup_u43() {
    log "Setup Ü4.3: gVisor"
    mkdir -p /opt/sandbox
    ns_create sandbox-required

    # RuntimeClass anlegen (falls runsc auf Nodes installiert ist)
    cat <<YAML | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
YAML

    # Bestehendes Deployment ohne gVisor
    cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: untrusted-job
  namespace: sandbox-required
spec:
  replicas: 1
  selector:
    matchLabels:
      app: untrusted-job
  template:
    metadata:
      labels:
        app: untrusted-job
    spec:
      containers:
      - name: job
        image: nginxinc/nginx-unprivileged:1.25
YAML

    log "Setup Ü4.3 fertig - User soll Deployment auf gvisor patchen"
    log "HINWEIS: Funktioniert nur wenn runsc auf den Nodes installiert ist"
}

teardown_u43() {
    log "Teardown Ü4.3"
    ns_delete sandbox-required
    kubectl delete runtimeclass gvisor --ignore-not-found
    rm -rf /opt/sandbox
}

# -------- Ü4.4: Cilium L7 Policy --------
setup_u44() {
    log "Setup Ü4.4: Cilium L7"
    mkdir -p /opt/cilium-test
    ns_create api-tier

    # read-api Service deployen
    cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: read-api
  namespace: api-tier
  labels:
    app: read-api
spec:
  containers:
  - name: api
    image: nginxinc/nginx-unprivileged:1.25
    ports:
    - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: read-api
  namespace: api-tier
spec:
  selector:
    app: read-api
  ports:
  - port: 8080
    targetPort: 8080
YAML

    log "Setup Ü4.4 fertig"
    log "VORAUSSETZUNG: Cluster muss Cilium als CNI nutzen mit L7 enabled"
}

teardown_u44() {
    log "Teardown Ü4.4"
    ns_delete api-tier
    rm -rf /opt/cilium-test
}

# -------- Ü4.5: Cilium mTLS --------
setup_u45() {
    log "Setup Ü4.5: Cilium mTLS"
    ns_create payment

    # Beide Services deployen
    for svc in payment-svc bank-connector; do
        cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $svc
  namespace: payment
  labels:
    app: $svc
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
YAML
    done

    log "Setup Ü4.5 fertig"
    log "VORAUSSETZUNG: Cilium mit --enable-mutual-authentication"
}

teardown_u45() {
    log "Teardown Ü4.5"
    ns_delete payment
}

# =============================================================
# 5. SUPPLY CHAIN SECURITY
# =============================================================

# -------- Ü5.1: Distroless Migration --------
setup_u51() {
    log "Setup Ü5.1: Dockerfile zum Umschreiben"
    mkdir -p /opt/build

    cat > /opt/build/Dockerfile <<'DOCKERFILE'
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y \
      python3 python3-pip \
      curl wget vim \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY main.py /app/main.py

CMD ["python3", "/app/main.py"]
DOCKERFILE

    cat > /opt/build/main.py <<'PYEOF'
print("Hello from CKS exercise")
PYEOF

    cat > /opt/build/requirements.txt <<'EOF'
requests==2.31.0
EOF

    log "Setup Ü5.1 fertig - /opt/build/Dockerfile vorhanden"
    log "User soll /opt/build/Dockerfile.distroless erstellen"
}

teardown_u51() {
    log "Teardown Ü5.1"
    rm -rf /opt/build
}

# -------- Ü5.2: Trivy Ignore-Liste --------
setup_u52() {
    log "Setup Ü5.2: Trivy"
    mkdir -p /opt/trivy

    if ! command -v trivy &> /dev/null; then
        log "WARNUNG: trivy nicht installiert!"
        log "Install: sudo apt-get install trivy oder docker run aquasec/trivy"
    fi

    log "Setup Ü5.2 fertig"
}

teardown_u52() {
    log "Teardown Ü5.2"
    rm -rf /opt/trivy
}

# -------- Ü5.3: ImagePolicyWebhook --------
setup_u53() {
    log "Setup Ü5.3: ImagePolicyWebhook"

    sudo mkdir -p /etc/kubernetes/admission /etc/kubernetes/webhook

    # Dummy-Kubeconfig für den Webhook (User würde echten Webhook brauchen)
    sudo tee /etc/kubernetes/webhook/image-policy-kubeconfig.yaml > /dev/null <<'YAML'
apiVersion: v1
kind: Config
clusters:
- name: image-policy-webhook
  cluster:
    server: https://image-policy-webhook.default.svc:443/policy
contexts:
- name: image-policy-webhook
  context:
    cluster: image-policy-webhook
current-context: image-policy-webhook
YAML

    log "Setup Ü5.3 fertig"
    log "WARNUNG: Aufgabe modifiziert kube-apiserver - Backup wird vom User erwartet"
    log "Echter Webhook-Service nicht enthalten - Pod-Creation wird fehlschlagen (was die Aufgabe so will)"
}

teardown_u53() {
    log "Teardown Ü5.3"
    ns_delete prod
    rm -rf /opt/admission

    # API-Server Backup zurückspielen
    if [ -f /root/kube-apiserver.yaml.bak ]; then
        log "API-Server Backup wird zurückgespielt..."
        sudo cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
        sudo rm /root/kube-apiserver.yaml.bak
        sleep 15
    fi

    sudo rm -rf /etc/kubernetes/admission /etc/kubernetes/webhook
}

# -------- Ü5.4: Cosign --------
setup_u54() {
    log "Setup Ü5.4: Cosign"
    mkdir -p /opt/cosign

    if ! command -v cosign &> /dev/null; then
        log "WARNUNG: cosign nicht installiert!"
        log "Install: go install github.com/sigstore/cosign/v2/cmd/cosign@latest"
    fi

    # Dummy-Keypair generieren (damit der Public Key existiert)
    if [ ! -f /opt/cosign/public.pem ]; then
        # Verwende openssl als Fallback - cosign braucht eigenes Format,
        # aber das reicht damit der Pfad existiert
        cd /opt/cosign
        if command -v cosign &> /dev/null; then
            COSIGN_PASSWORD="" cosign generate-key-pair 2>/dev/null && \
                mv cosign.pub public.pem
        else
            # Fallback: dummy PEM
            openssl genrsa -out priv.pem 2048
            openssl rsa -in priv.pem -pubout -out public.pem 2>/dev/null
            rm priv.pem
        fi
        cd - > /dev/null
    fi

    log "Setup Ü5.4 fertig - Public Key in /opt/cosign/public.pem"
    log "HINWEIS: Tatsächlicher Verify-Test braucht echtes signiertes Image"
}

teardown_u54() {
    log "Teardown Ü5.4"
    rm -rf /opt/cosign
}

# -------- Ü5.5: Kubesec --------
setup_u55() {
    log "Setup Ü5.5: Kubesec mit 3 Test-Manifesten"
    mkdir -p /opt/manifests /opt/scores

    # Bad: kein securityContext, privileged
    cat > /opt/manifests/pod-bad.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: bad
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      privileged: true
YAML

    # Medium: einige Settings, aber nicht alle
    cat > /opt/manifests/pod-medium.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: medium
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
YAML

    # Good: alles gehärtet
    cat > /opt/manifests/pod-good.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: good
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
YAML

    if ! command -v kubesec &> /dev/null; then
        log "WARNUNG: kubesec nicht installiert!"
        log "Install: curl -sSX GET https://api.kubesec.io/v2/scan -o /usr/local/bin/kubesec"
        log "Oder: docker run kubesec/kubesec:v2"
    fi

    log "Setup Ü5.5 fertig"
}

teardown_u55() {
    log "Teardown Ü5.5"
    rm -rf /opt/manifests /opt/scores
}

# =============================================================
# 6. MONITORING, LOGGING, RUNTIME SECURITY
# =============================================================

# -------- Ü6.1: Falco Crypto-Miner Rule --------
setup_u61() {
    log "Setup Ü6.1: Falco Crypto-Miner"

    if ! systemctl is-active falco &> /dev/null && \
       ! command -v falco &> /dev/null; then
        log "WARNUNG: Falco nicht installiert/aktiv"
        log "Install: curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg"
    fi

    sudo mkdir -p /etc/falco/rules.d

    log "Setup Ü6.1 fertig - User schreibt /etc/falco/rules.d/crypto-miner.yaml"
}

teardown_u61() {
    log "Teardown Ü6.1"
    sudo rm -f /etc/falco/rules.d/crypto-miner.yaml
    kubectl delete pod miner-test --ignore-not-found 2>/dev/null || true
    sudo systemctl restart falco 2>/dev/null || true
}

# -------- Ü6.2: Audit Policy Levels --------
setup_u62() {
    log "Setup Ü6.2: Audit Policy"

    sudo mkdir -p /etc/kubernetes/audit /var/log/kubernetes

    log "Setup Ü6.2 fertig"
    log "WARNUNG: Aufgabe modifiziert kube-apiserver - User soll Backup machen"
}

teardown_u62() {
    log "Teardown Ü6.2"

    # API-Server Backup zurückspielen
    if [ -f /root/kube-apiserver.yaml.bak ]; then
        log "API-Server Backup wird zurückgespielt..."
        sudo cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
        sudo rm /root/kube-apiserver.yaml.bak
        sleep 15
    fi

    sudo rm -rf /etc/kubernetes/audit
    sudo rm -f /var/log/kubernetes/audit.log*
}

# -------- Ü6.3: Falco Alert Filterung --------
setup_u63() {
    log "Setup Ü6.3: Falco Alert-Log mit Sample-Daten generieren"
    mkdir -p /opt/falco-analysis
    sudo mkdir -p /var/log/falco

    # Sample Alert-Log generieren (JSON Lines Format wie Falco)
    NOW=$(date -u +%Y-%m-%dT%H:%M:%S)
    LAST_HOUR=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S)
    OLD=$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)

    sudo tee /var/log/falco/alerts.log > /dev/null <<EOF
{"time":"${LAST_HOUR}.000000000Z","priority":"Critical","output":"Shell spawned","output_fields":{"container.name":"webapp-1","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Critical","output":"Crypto miner detected","output_fields":{"container.name":"compromised-1","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Critical","output":"Sensitive file read","output_fields":{"container.name":"webapp-1","user.name":"www-data"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Critical","output":"Privilege escalation","output_fields":{"container.name":"webapp-1","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Critical","output":"Suspicious network connection","output_fields":{"container.name":"compromised-1","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Error","output":"Container drift","output_fields":{"container.name":"webapp-2","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Error","output":"Modified binary","output_fields":{"container.name":"webapp-2","user.name":"root"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Warning","output":"Outbound connection","output_fields":{"container.name":"webapp-1","user.name":"www-data"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Warning","output":"DNS lookup","output_fields":{"container.name":"webapp-3","user.name":"www-data"}}
{"time":"${LAST_HOUR}.000000000Z","priority":"Notice","output":"Process spawned","output_fields":{"container.name":"webapp-1","user.name":"www-data"}}
{"time":"${OLD}.000000000Z","priority":"Critical","output":"Old critical event","output_fields":{"container.name":"webapp-1","user.name":"root"}}
{"time":"${OLD}.000000000Z","priority":"Informational","output":"Info event","output_fields":{"container.name":"webapp-1","user.name":"www-data"}}
EOF

    log "Setup Ü6.3 fertig - 12 Sample-Events in /var/log/falco/alerts.log"
}

teardown_u63() {
    log "Teardown Ü6.3"
    rm -rf /opt/falco-analysis
    sudo rm -f /var/log/falco/alerts.log
}

# -------- Ü6.4: Container Immutability mehrere Deployments --------
setup_u64() {
    log "Setup Ü6.4: Mehrere Deployments ohne readOnlyRootFilesystem"
    mkdir -p /opt/immutability
    ns_create prod-services

    # 4 Deployments - 2 ohne readOnly, 1 mit, 1 mit anderem Setting
    # without_ro (sollten gefixt werden):
    for app in api-server worker-1; do
        cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: prod-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
      - name: app
        image: nginxinc/nginx-unprivileged:1.25
YAML
    done

    # with_ro (sollte ignoriert werden):
    cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: prod-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: app
        image: nginxinc/nginx-unprivileged:1.25
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
YAML

    log "Setup Ü6.4 fertig - 2 Deployments ohne readOnly, 1 mit"
}

teardown_u64() {
    log "Teardown Ü6.4"
    ns_delete prod-services
    rm -rf /opt/immutability
}

# -------- Ü6.5: Privilegierte hostPath Mounts --------
setup_u65() {
    log "Setup Ü6.5: Pods mit gefährlichen hostPath Mounts"
    mkdir -p /opt/posture

    # Verschiedene Pods mit unterschiedlichen Risiken in default Namespace
    cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: docker-sock-user
  namespace: default
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    volumeMounts:
    - name: docker
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker
    hostPath:
      path: /var/run/docker.sock
---
apiVersion: v1
kind: Pod
metadata:
  name: host-root-pod
  namespace: default
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
---
apiVersion: v1
kind: Pod
metadata:
  name: etc-mounter
  namespace: kube-system
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    volumeMounts:
    - name: etc
      mountPath: /host-etc
  volumes:
  - name: etc
    hostPath:
      path: /etc
---
apiVersion: v1
kind: Pod
metadata:
  name: harmless-pod
  namespace: default
spec:
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
YAML

    log "Setup Ü6.5 fertig - 3 gefährliche Pods + 1 harmloser"
}

teardown_u65() {
    log "Teardown Ü6.5"
    kubectl delete pod docker-sock-user host-root-pod harmless-pod -n default --ignore-not-found
    kubectl delete pod etc-mounter -n kube-system --ignore-not-found
    rm -rf /opt/posture
}

# =============================================================
# DISPATCHER
# =============================================================

# Liste aller Aufgaben (für list und all-Befehle)
ALL_TASKS="u11 u12 u13 u14 u15 u21 u22 u23 u24 u31 u32 u33 u41 u42 u43 u44 u45 u51 u52 u53 u54 u55 u61 u62 u63 u64 u65"

show_usage() {
    cat <<USAGE
CKS Übungs-Setup

Usage:
  $0 setup <task>      - Bereitet eine Aufgabe vor (z.B. u11)
  $0 teardown <task>   - Räumt eine Aufgabe weg
  $0 list              - Listet alle Aufgaben
  $0 setup-all         - Bereitet ALLES vor (Vorsicht!)
  $0 teardown-all      - Räumt ALLES weg

Beispiele:
  $0 setup u11         # Bereitet Ü1.1 vor
  $0 teardown u43      # Räumt Ü4.3 weg
  $0 list              # Zeigt alle Aufgaben

Verfügbare Aufgaben:
  Cluster Setup:           u11 u12 u13 u14 u15
  Cluster Hardening:       u21 u22 u23 u24
  System Hardening:        u31 u32 u33
  Microservice Vulns:      u41 u42 u43 u44 u45
  Supply Chain Security:   u51 u52 u53 u54 u55
  Monitoring/Logging/Runt: u61 u62 u63 u64 u65
USAGE
}

list_tasks() {
    cat <<LIST
Verfügbare Übungsaufgaben:

CLUSTER SETUP (15%)
  u11 - NetworkPolicy 3-Tier (frontend/backend/database)
  u12 - kube-bench CIS Benchmark
  u13 - Ingress TLS für Microservice
  u14 - Cloud Metadata Endpoint blockieren
  u15 - kubeadm Binary Verification

CLUSTER HARDENING (15%)
  u21 - RBAC: Minimale Permissions für CI-Bot
  u22 - Default ServiceAccount ohne Token-Mount
  u23 - API Server: Anonyme Auth deaktivieren
  u24 - Kubernetes Worker-Node Upgrade

SYSTEM HARDENING (10%)
  u31 - AppArmor Custom Profile mit Netzwerk-Beschränkung
  u32 - Seccomp RuntimeDefault via PSS enforcen
  u33 - Unbenötigte Linux-Pakete identifizieren

MINIMIZE MICROSERVICE VULNERABILITIES (20%)
  u41 - PSS baseline Namespace
  u42 - Secret Encryption-at-Rest verifizieren
  u43 - gVisor RuntimeClass + Pod Migration
  u44 - Cilium L7 Policy (HTTP-Methoden)
  u45 - mTLS via Cilium

SUPPLY CHAIN SECURITY (20%)
  u51 - Distroless Image Migration
  u52 - Trivy mit Ignore-Liste
  u53 - ImagePolicyWebhook
  u54 - Cosign Image-Signatur verifizieren
  u55 - Kubesec Static Analysis im CI

MONITORING, LOGGING, RUNTIME SECURITY (20%)
  u61 - Falco Rule: Crypto-Miner Detection
  u62 - Audit Policy mit unterschiedlichen Levels
  u63 - Falco-Alerts nach Severity filtern
  u64 - Container Immutability für mehrere Deployments
  u65 - Pods mit privilegierten Mounts identifizieren
LIST
}

# Main dispatch
case "${1:-}" in
    setup)
        if [ -z "${2:-}" ]; then
            log "ERROR: Bitte Aufgabe angeben (z.B. setup u11)"
            exit 1
        fi
        FUNC="setup_$2"
        if declare -f "$FUNC" > /dev/null; then
            "$FUNC"
        else
            log "ERROR: Aufgabe '$2' unbekannt. './$0 list' für Übersicht"
            exit 1
        fi
        ;;
    teardown)
        if [ -z "${2:-}" ]; then
            log "ERROR: Bitte Aufgabe angeben (z.B. teardown u11)"
            exit 1
        fi
        FUNC="teardown_$2"
        if declare -f "$FUNC" > /dev/null; then
            "$FUNC"
        else
            log "ERROR: Aufgabe '$2' unbekannt"
            exit 1
        fi
        ;;
    setup-all)
        log "Setup ALLER Aufgaben..."
        for task in $ALL_TASKS; do
            "setup_$task" || log "Fehler bei $task - überspringe"
        done
        log "Setup-All fertig"
        ;;
    teardown-all)
        log "Teardown ALLER Aufgaben..."
        for task in $ALL_TASKS; do
            "teardown_$task" || log "Fehler bei $task - überspringe"
        done
        log "Teardown-All fertig"
        ;;
    list)
        list_tasks
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
