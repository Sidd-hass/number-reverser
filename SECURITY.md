# Security Architecture & Tooling Report (SECURITY.md)

This document details the security posture, defensive engineering choices, scanning outcomes, and compliance tooling implemented for the **Number Reverser** service, designed for regulated cloud environments.

---

## 1. Tooling Selection & Architecture Rationale

| Layer | Selected Tool | Rationale vs Alternatives |
| :--- | :--- | :--- |
| **IaC Scanning** | **Trivy (`trivy config`)** | Consolidated vulnerability and configuration scanner across both infrastructure code and container layers. Evaluated against **tfsec** and **Checkov**; Trivy provides unified SARIF output, zero external Python dependencies in CI, and active CVE/misconfiguration rule updates. |
| **Container Scanning** | **Trivy (`trivy image`)** | Fast, comprehensive OS and language-package vulnerability database. Configured with `--exit-code 1 --severity CRITICAL` to strictly fail builds on unresolved critical vulnerabilities. |
| **SBOM Generation** | **Syft (`anchore/sbom-action`)** | Generates standard SPDX and CycloneDX Software Bill of Materials directly from the built OCI container layers. Published as an immutable pipeline build artifact to guarantee supply-chain transparency and inventory auditability (NIST SP 800-218 / Executive Order 14028). |
| **Image Signing & Verification** | **Cosign (Sigstore)** | Employs keyless image signing backed by GitHub Actions OIDC federation (`id-token: write`). Avoids long-lived cryptographic signing keys that can leak; binds image signatures to the ephemeral GitHub Actions workflow identity and records them immutably on the Rekor transparency log. Signature is cryptographically verified before deployment. |
| **Kubernetes Policy Enforcement** | **Kyverno** | Native Kubernetes declarative policy engine. Evaluated against **OPA/Gatekeeper**; Kyverno policies are standard Kubernetes CRDs that eliminate the operational friction of learning and debugging Rego DSL code. Validates admission requests in real-time. |
| **Container Base Image** | **`python:3.13-slim`** | Balances minimal attack surface with Python wheel compatibility. Compared to Alpine (`musl`-libc), Debian slim avoids subtle glibc compilation vulnerabilities and DNS resolver quirks while keeping image size under 150MB and zero critical CVEs. |
| **Network Segmentation** | **Kubernetes NetworkPolicy** | Enforces zero-trust microsegmentation directly inside the cluster, restricting ingress to HTTP port 8000 and locking all egress to DNS resolution only. |

---

## 2. Scan Findings & Remediations

### A. Infrastructure as Code (Terraform) Scans
When running static analysis against the Terraform infrastructure, initial scans highlighted key compliance requirements for regulated clouds:

1. **AWS EC2 Instance Metadata Service (IMDSv1 Vulnerability)**
   - *Finding*: Default EC2 instances permit IMDSv1, exposing credentials to Server-Side Request Forgery (SSRF) attacks.
   - *Remediation*: Explicitly enforced IMDSv2 in `infra/modules/compute/main.tf`:
     ```hcl
     metadata_options {
       http_endpoint               = "enabled"
       http_tokens                 = "required"
       http_put_response_hop_limit = 1
       instance_metadata_tags      = "disabled"
     }
     ```
2. **Unencrypted Storage Volumes**
   - *Finding*: Default EBS volumes could store sensitive cache data in plaintext.
   - *Remediation*: Enforced AES-256 encryption on root EBS volume:
     ```hcl
     root_block_device {
       volume_size = var.root_volume_size
       volume_type = "gp3"
       encrypted   = true
     }
     ```
3. **Exposed Administrative Ports (SSH Port 22 / Kubernetes Port 6443)**
   - *Finding*: Standard tutorials open port 22 or 6443 to `0.0.0.0/0`, creating a continuous brute-force and credential stuffing surface.
   - *Remediation*: Completely removed Port 22 and 6443 ingress from `aws_security_group`. Access is managed exclusively through AWS Systems Manager (SSM) with IAM Session Manager, leaving zero management ports open to the public internet.
4. **Outbound Traffic Egress Control & Trivy AVD-AWS-0104 Finding**
   - *Finding*: Trivy flagged `AVD-AWS-0104` (Critical) on all egress rules pointing to `0.0.0.0/0`.
   - *Architectural Root Cause*: Scanners flag any rule opening outbound internet access. However, a single-node trial/free-tier host without costly NAT Gateways ($32/month) or AWS VPC Endpoints ($7/month each) must contact public CDN endpoints to pull Docker Hub images, fetch Ubuntu security patches, and communicate with the AWS Systems Manager (SSM) regional endpoint.
   - *Professional DevSecOps Remediation (No `continue-on-error` bypass)*:
     - **DNS (Port 53 UDP/TCP)**: Scoped egress strictly to the internal VPC CIDR (`var.vpc_cidr` / Amazon Route 53 VPC Resolver at `10.20.0.2`), completely removing `0.0.0.0/0` for DNS.
     - **HTTPS / HTTP (Ports 443 and 80)**: Rather than disabling the scanner (`continue-on-error: true`), formal exception tracking was implemented using inline `# trivy:ignore:AVD-AWS-0104` comments with documented technical justifications and an audited `.trivyignore` policy file.
     - **Regulated Production Transition**: In enterprise production, this exception is permanently closed by placing worker nodes in private subnets, establishing AWS PrivateLink interface endpoints for SSM/ECR, and routing internet-bound traffic through an egress proxy with strict FQDN/domain allowlisting.

### B. Container Image Scanning
- **Base Image Audit**: Audited `python:3.13-slim` with Trivy.
- **Pipeline Gate**: Configured to break the build on any finding with severity `CRITICAL`.
- **Runtime Privilege**: Configured non-root execution inside the container with UID/GID `10001:10001` and disabled bytecode compilation (`PYTHONDONTWRITEBYTECODE=1`).

---

## 3. Admission Control & Policy Enforcement

Four Kyverno policies are defined in `k8s/policies/` with `validationFailureAction: Enforce`:

1. **`disallow-privileged-containers`**:
   - Blocks pods specifying `securityContext.privileged: true`.
   - Prevents containers from gaining direct root access to host kernel namespaces and hardware devices.
2. **`require-run-as-non-root`**:
   - Requires `securityContext.runAsNonRoot: true`.
   - Neutralizes arbitrary UID 0 execution, mitigating Linux container breakout techniques (e.g. CVE-2024-21626).
3. **`require-resource-requests-limits`**:
   - Requires explicit `cpu` and `memory` specifications for both requests and limits.
   - Protects node availability against denial-of-service and "noisy neighbor" starvation attacks.
4. **`disallow-latest-tag`**:
   - Rejects manifests using the mutable `:latest` tag.
   - Enforces deterministic, auditable release tracking by requiring immutable semver tags or image digests.

---

## 4. Network Isolation & Pod Security Standards

### Ingress & Egress Segmentation
The service runs behind an isolated `NetworkPolicy` (`k8s/base/networkpolicy.yaml`):
- **Ingress**: Strictly permits ingress traffic to container port `8000`.
- **Egress**: Completely blocks all outbound egress traffic **except** UDP/TCP port 53 to the `kube-system` namespace for DNS lookups.
- **Impact**: In the event of a remote code execution vulnerability, an attacker cannot establish outbound command-and-control (C2) reverse shells or exfiltrate environment memory to the public internet.

### Pod Security Standards (PSS)
The deployment namespace (`number-reverser`) is labeled with:
```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```
This activates Kubernetes built-in admission checks requiring read-only root filesystems, non-root users, and the dropping of all Linux capabilities (`drop: ["ALL"]`).

---

## 5. Secrets Management Compliance

### Compliance Statement
**Zero secrets, passwords, or cloud credentials are committed to this repository.**

### Implementation & Stubbing Rationale
In accordance with regulated enterprise controls:
- **CI/CD Pipeline**: Relies on short-lived OpenID Connect (OIDC) identity tokens exchanged with AWS and Sigstore, eliminating long-lived static AWS access keys or signing certificates.
- **Application Secrets**: The application is stateless and requires no database credentials. However, a secret template (`k8s/base/secrets.template.yaml`) is provided to demonstrate how operational secrets are defined.
- **Production Integration**: In a production VPC, secrets are managed through **External Secrets Operator (ESO)** synchronized with **AWS Secrets Manager** or **HashiCorp Vault**, with encryption keys managed by dedicated AWS KMS customer-managed keys (CMKs).

---

## 6. Future Roadmap (Next Steps with Extended Time / Budget)

If advancing this system toward SOC 2 Type II, FedRAMP, or ISO 27001 certification, the following extensions would be introduced:

1. **Runtime Threat Detection (Falco / Tracee)**:
   - Deploy Falco daemonset on cluster nodes to monitor kernel syscalls via eBPF, alerting on abnormal process executions, `/tmp` executable spawning, or unexpected binary calls.
2. **CIS Kubernetes Benchmarking (`kube-bench`)**:
   - Automate scheduled runs of Aqua Security's `kube-bench` to verify node-level compliance against the CIS Kubernetes Benchmark.
3. **Policy-as-Code for Terraform Plans (Conftest / OPA)**:
   - Integrate Conftest into `.github/workflows/terraform.yml` to evaluate `terraform plan -out=tfplan.json` against custom Rego policies before `terraform apply` can execute.
4. **Mutual TLS & Service Mesh (Cilium / Istio)**:
   - Introduce Cilium with eBPF for wire-level WireGuard encryption, transparent mTLS, and Layer-7 HTTP access logging without sidecar overhead.
5. **Dynamic Vulnerability Assessment (DAST)**:
   - Integrate OWASP ZAP or StackHawk into the staging deployment pipeline to test HTTP endpoints against input fuzzing, header misconfigurations, and payload tampering.

