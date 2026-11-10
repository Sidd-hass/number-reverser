# Number Reverser — Live Demo & Walkthrough Runbook

This runbook contains the end-to-end command reference, architectural defense talking points, interview Q&A cheat sheet, and exact AWS cost analysis for the **Number Reverser** project.

---

## 1. 24-Hour AWS Infrastructure Cost Analysis (`ap-south-1`)

The provisioned infrastructure was deliberately designed to avoid costly managed control planes (such as AWS EKS at \$73/month) or NAT Gateways (\$32/month each).

### Exact Daily Cost Breakdown (24-Hour Continuous Run)

| AWS Component | Specifications | Hourly Rate | 24-Hour Cost | Free Tier Eligible? |
| :--- | :--- | :--- | :--- | :--- |
| **EC2 Compute** | `t3.medium` (2 vCPU, 4 GiB RAM) | \$0.0416 / hr | **\$0.998** | Charged against trial credits |
| **EBS Storage** | 30 GiB `gp3` (Encrypted) | \$0.0037 / hr | **\$0.088** | 100% Free under 30GB/mo tier |
| **Public IPv4** | In-use public IPv4 address | \$0.0050 / hr | **\$0.120** | AWS standard IPv4 rate |
| **VPC & Networking** | VPC, Subnet, IGW, Route Table | \$0.0000 | **\$0.000** | Always 100% Free |
| **Security Groups** | Custom ingress/egress rules | \$0.0000 | **\$0.000** | Always 100% Free |
| **IAM & Systems Manager**| Instance Profile & SSM Session | \$0.0000 | **\$0.000** | Always 100% Free |
| **TOTAL (24 Hours)** | | | **~\$1.20 USD** (₹100 INR) | **\$0.00 with trial credits** |

> **Cost Optimization Tip**: If you run the environment only for your 1–2 hour testing and demo recording window, the total AWS charge is **less than \$0.10 USD (ten cents)**.

---

## 2. Step-by-Step Execution Transcript (How It Was Deployed)

### Step 1: Provision Cloud Infrastructure (Terraform)
```powershell
cd c:\Users\jal\Desktop\projects\number-reverse\number-reverser\infra\environments\dev

# 1. Initialize Terraform
terraform init -backend=false -input=false

# 2. Preview resources (17 resources planned)
terraform plan

# 3. Apply infrastructure
terraform apply -auto-approve
```
*Outputs: `ec2_public_ip` (e.g. `13.206.250.225`), `ec2_instance_id` (e.g. `i-0af470d0c1f583dc9`).*

---

### Step 2: Automated Bootstrap (Cloud-Init on EC2)
Upon boot, [`user_data.sh`](file:///c:/Users/jal/Desktop/projects/number-reverse/number-reverser/infra/modules/compute/user_data.sh) automatically installs:
1. System prerequisites (`curl`, `iptables`).
2. **k3s** lightweight Kubernetes (`v1.37.2+k3s1`).
3. **Kyverno** admission controller (`v1.12.5`).
4. **ArgoCD** GitOps controller (`stable`).

#### Verify via AWS Systems Manager (No open SSH):
```powershell
# Verify SSM connection
aws ssm describe-instance-information --region ap-south-1 --filters "Key=InstanceIds,Values=<EC2_INSTANCE_ID>"

# Inspect cloud-init logs and verify k3s node readiness
aws ssm send-command `
  --region ap-south-1 `
  --instance-ids "<EC2_INSTANCE_ID>" `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['tail -n 20 /var/log/user-data.log', 'kubectl get nodes']"
```

---

### Step 3: Register GitOps Applications in ArgoCD
```powershell
# Apply ArgoCD Application CRDs from GitHub
aws ssm send-command `
  --region ap-south-1 `
  --instance-ids "<EC2_INSTANCE_ID>" `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['kubectl apply -f https://raw.githubusercontent.com/Sidd-hass/number-reverser/master/argocd/policies-application.yaml', 'kubectl apply -f https://raw.githubusercontent.com/Sidd-hass/number-reverser/master/argocd/application.yaml']"
```

#### Check GitOps Sync & Pod Health:
```powershell
aws ssm send-command `
  --region ap-south-1 `
  --instance-ids "<EC2_INSTANCE_ID>" `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['kubectl get applications -A', 'kubectl get pods -n number-reverser', 'kubectl get clusterpolicies']"
```
*Expected: `number-reverser Synced/Healthy`, `2/2 Running`, Kyverno policies `Enforce/Ready`.*

---

## 3. Live Demo & Verification Commands

Run these commands directly from your local terminal against `http://<EC2_PUBLIC_IP>`:

### 1. Liveness Probe
```bash
curl -i -s http://<EC2_PUBLIC_IP>/health
```
*Output: `HTTP/1.1 200 OK` ➔ `{"status":"ok"}`*

### 2. Standard Number Reversal (12345 ➔ 54321)
```bash
curl -s -X POST http://<EC2_PUBLIC_IP>/reverse -H "Content-Type: application/json" -d '{"number": 12345}'
```
*Output: `{"input":12345,"reversed":54321}`*

### 3. Negative Number & Trailing Zeros (-1200 ➔ -21)
```bash
curl -s -X POST http://<EC2_PUBLIC_IP>/reverse -H "Content-Type: application/json" -d '{"number": -1200}'
```
*Output: `{"input":-1200,"reversed":-21}`*

### 4. Signed 64-bit Integer Overflow Rejection
```bash
curl -i -s -X POST http://<EC2_PUBLIC_IP>/reverse -H "Content-Type: application/json" -d '{"number": 8999999999999999999}'
```
*Output: `HTTP/1.1 422 Unprocessable Entity` ➔ `{"detail":"Reversed result exceeds signed 64-bit integer range"}`*

### 5. String / Float Input Rejection
```bash
curl -i -s -X POST http://<EC2_PUBLIC_IP>/reverse -H "Content-Type: application/json" -d '{"number": "hello"}'
```
*Output: `HTTP/1.1 422 Unprocessable Entity` ➔ `{"detail":[{"msg":"Input should be a valid integer"}]}`*

### 6. Interactive Web UI
Open **`http://<EC2_PUBLIC_IP>/`** in any browser.

### 7. Live Security Policy Defense (Kyverno)
Demonstrate that Kyverno blocks unhardened privileged containers:
```powershell
aws ssm send-command `
  --region ap-south-1 `
  --instance-ids "<EC2_INSTANCE_ID>" `
  --document-name "AWS-RunShellScript" `
  --parameters "commands=['kubectl run test-priv --image=nginx --privileged -n number-reverser']"
```
*Output: Denied by admission webhook: `violates PodSecurity "restricted:latest": privileged`.*

---

## 4. Interview Defense & Architectural Q&A Cheat Sheet

### Q1: "Why k3s on EC2 instead of managed EKS or GKE?"
> **Answer**: Managed EKS costs \$73/month just for the control plane and takes 15–20 minutes to stand up. For a trial environment with a \$0 spend requirement, single-node k3s on a `t3.medium` gives full CNCF-certified Kubernetes with admission webhooks, CRDs, and CNI support in under 60 seconds. In production, we swap the compute module for EKS without changing a single line of our Kubernetes manifests or Kyverno policies.

### Q2: "How did you address the Trivy `AVD-AWS-0104` egress violation?"
> **Answer**: `AVD-AWS-0104` flags `0.0.0.0/0` outbound as Critical. Rather than using `continue-on-error: true` (which creates scanner theater), we used defense-in-depth:
> 1. We architecturally eliminated `0.0.0.0/0` on DNS by scoping egress strictly to the internal VPC CIDR (`10.20.0.0/16`) where AWS Route 53 resolver lives.
> 2. For ports 443 and 80, we established an audited exception policy via inline `# trivy:ignore:AVD-AWS-0104` comments with documented justifications and an audited `.trivyignore` file.
> In enterprise production, this exception is closed by deploying AWS PrivateLink VPC endpoints for SSM/ECR and an egress proxy with domain-name allowlisting.

### Q3: "Why did you enforce signed 64-bit limits on reversal?"
> **Answer**: Python natively supports arbitrarily large integers. However, microservices feed downstream systems (PostgreSQL `BIGINT`, Kafka, Go/Rust microservices) that strictly enforce 64-bit boundaries. An input within $[-2^{63}, 2^{63}-1]$ (like `8999999999999999999`) produces an overflow when reversed. We bound both input and reversed output to signed 64-bit limits, rejecting overflows with HTTP 422 to protect downstream consumers.

### Q4: "Why Kyverno instead of OPA Gatekeeper?"
> **Answer**: Kyverno uses standard Kubernetes declarative YAML rather than an external DSL (Rego). In regulated platforms, policies must be easily audited and maintained by platform teams without requiring separate compiler toolchains. Kyverno policies are standard CRDs that integrate natively with GitOps (ArgoCD).

### Q5: "Why Keyless Signing with Cosign?"
> **Answer**: Traditional signing requires long-lived private keys stored in CI secrets, which are susceptible to leakage and rotation failure. Keyless Cosign uses Sigstore (Fulcio CA + Rekor transparency log) backed by GitHub Actions OIDC tokens. The signing identity is short-lived (10 mins), cryptographically bound to the GitHub workflow run, and verifiable anywhere without managing static keys.

### Q6: "Why is SSH port 22 completely closed?"
> **Answer**: Opening port 22 invites brute-force attacks and requires managing private keys. We attached `AmazonSSMManagedInstanceCore` and administer the node exclusively via AWS Systems Manager. This provides audited, IAM-governed, MFA-compatible shell access via AWS CloudTrail with zero open management ports.

---

## 5. Teardown & Post-Destroy Verification

### Execute Teardown
```powershell
cd c:\Users\jal\Desktop\projects\number-reverse\number-reverser\infra\environments\dev
terraform destroy -auto-approve
```

### Post-Teardown Verification Audit (Confirm 0 Resources Remain)
```powershell
# 1. Confirm EC2 is terminated
aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:Project,Values=number-reverser" "Name=instance-state-name,Values=running,stopped,pending" --query "Reservations[*].Instances[*].InstanceId" --output text

# 2. Confirm EBS volumes deleted
aws ec2 describe-volumes --region ap-south-1 --filters "Name=tag:Project,Values=number-reverser" --query "Volumes[*].VolumeId" --output text

# 3. Confirm custom VPC deleted
aws ec2 describe-vpcs --region ap-south-1 --filters "Name=tag:Project,Values=number-reverser" --query "Vpcs[*].VpcId" --output text

# 4. Confirm IAM role deleted
aws iam list-roles --query "Roles[?RoleName=='number-reverser-ec2-role'].RoleName" --output text
```
*All 4 commands should return empty, confirming zero active resources and zero continuing spend.*

