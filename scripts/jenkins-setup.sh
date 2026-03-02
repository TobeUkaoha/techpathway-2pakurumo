#!/bin/bash
# ============================================================
# Jenkins Bootstrap Script for Amazon Linux 2023 / Ubuntu 22.04
# Run as: sudo bash jenkins-setup.sh
# ============================================================
set -euo pipefail

echo "=== TechPathway Jenkins Setup Script ==="

# ── Detect OS ──────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"; exit 1
fi

echo "Detected OS: $OS"

# ── System Update ──────────────────────────────────────────
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git unzip fontconfig ca-certificates gnupg lsb-release

elif [[ "$OS" == "amzn" ]]; then
    yum update -y
    yum install -y curl wget git unzip fontconfig
fi

# ── Install Java 21 (Jenkins requirement) ──────────────────
echo "--- Installing Java 21 ---"
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt-get install -y openjdk-21-jdk
elif [[ "$OS" == "amzn" ]]; then
    yum install -y java-21-amazon-corretto
fi

java -version

# ── Install Jenkins ────────────────────────────────────────
echo "--- Installing Jenkins ---"
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
        | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
        https://pkg.jenkins.io/debian-stable binary/" \
        > /etc/apt/sources.list.d/jenkins.list
    apt-get update -y
    apt-get install -y jenkins

elif [[ "$OS" == "amzn" ]]; then
    wget -O /etc/yum.repos.d/jenkins.repo \
        https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum install -y jenkins
fi

systemctl enable jenkins
systemctl start jenkins

# ── Install Docker ─────────────────────────────────────────
echo "--- Installing Docker ---"
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

elif [[ "$OS" == "amzn" ]]; then
    yum install -y docker
fi

systemctl enable docker
systemctl start docker

# Add jenkins user to docker group so Jenkins can run docker commands
usermod -aG docker jenkins

# ── Install AWS CLI v2 ─────────────────────────────────────
echo "--- Installing AWS CLI v2 ---"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
elif [[ "$ARCH" == "aarch64" ]]; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
fi
unzip -q /tmp/awscliv2.zip -d /tmp/
/tmp/aws/install
aws --version

# ── Restart Jenkins to pick up docker group membership ─────
echo "--- Restarting Jenkins ---"
systemctl restart jenkins

# ── Print Jenkins initial admin password ───────────────────
echo ""
echo "============================================================"
echo "✅ Jenkins setup complete!"
echo ""
echo "Jenkins is running on port 8080"
echo "Access: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "Initial Admin Password:"
sleep 5
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || \
    echo "(wait a moment and run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "============================================================"
