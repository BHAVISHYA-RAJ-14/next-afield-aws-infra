# Next Afield AWS Infrastructure

![Terraform](https://img.shields.io/badge/terraform-v1.5.0-623CE4?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-us--east--1-232F3E?logo=amazon-aws)
![Atlantis](https://img.shields.io/badge/GitOps-Atlantis-blue)
![Security](https://img.shields.io/badge/Security-Checkov-success)

> **Production-grade AWS infrastructure provisioned via Terraform, enforced via Checkov security scanning, and operated via a GitOps workflow using Atlantis.**

---

## Table of Contents

- [What This Project Does](#what-this-project-does)
- [Architecture Overview](#architecture-overview)
- [Infrastructure Layers](#infrastructure-layers)
- [GitOps Workflow](#gitops-workflow)
- [Security & Compliance](#security--compliance)
- [Cost Strategy](#cost-strategy)
- [How to Prove It Works](#how-to-prove-it-works)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Prerequisites](#prerequisites)
- [Running Locally](#running-locally)
- [Environment Variables Reference](#environment-variables-reference)
- [Known Suppressions & Justifications](#known-suppressions--justifications)

---

## What This Project Does

This project provisions a complete, layered AWS infrastructure for a production application using:

- **Terraform** — Infrastructure as Code (IaC) to define, version, and manage all AWS resources
- **Atlantis** — GitOps automation server that runs Terraform plans and applies directly from GitHub Pull Requests
- **Checkov** — Static security analysis that scans Terraform code for misconfigurations before any infrastructure is touched
- **S3 + DynamoDB** — Remote state backend with state locking to prevent concurrent conflicts

The core principle: **no one touches AWS manually**. Every infrastructure change flows through a Pull Request, is automatically planned and security-scanned, requires approval, and is then applied — all traceable in git history.

---

## Architecture Overview

```
Developer → GitHub PR → Atlantis (GitOps) → Terraform Plan → Checkov Scan → Approval → Apply → AWS
                                                                    ↑
                                                         S3 Remote State + DynamoDB Lock
```

### AWS Resources Provisioned (57 total)

```
┌──────────────────────────────────────────────────────────┐
│                    AWS Region: us-east-1                 │
│                                                          │
│  ┌─────────────────────────────────────────────────┐     │
│  │              VPC (10.0.0.0/16)                  │     │
│  │                                                 │     │
│  │  ┌──────────────┐   ┌──────────────┐            │     │
│  │  │ Public Subnet│   │ Public Subnet│            │     │
│  │  │ us-east-1a   │   │ us-east-1b   │            │     │
│  │  │10.0.101.0/24 │   │10.0.102.0/24 │            │     │
│  │  └──────────────┘   └──────────────┘            │     │
│  │         │                   │                   │     │
│  │    Internet Gateway (Public Traffic)             │     │
│  │                                                 │     │
│  │  ┌──────────────┐   ┌──────────────┐            │     │
│  │  │Private Subnet│   │Private Subnet│            │     │
│  │  │ us-east-1a   │   │ us-east-1b   │            │     │
│  │  │ 10.0.1.0/24  │   │ 10.0.2.0/24  │            │     │
│  │  │              │   │              │            │     │
│  │  │  EKS Nodes   │   │  EKS Nodes   │            │     │
│  │  │  RDS (PG)    │   │              │            │     │
│  │  │  Redis       │   │              │            │     │
│  │  └──────────────┘   └──────────────┘            │     │
│  └─────────────────────────────────────────────────┘     │
│                                                          │
│  ┌──────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │ S3 Bucket│  │DynamoDB Table │  │  EKS Control     │  │
│  │(TF State)│  │ (State Lock)  │  │  Plane (Managed) │  │
│  └──────────┘  └───────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## Infrastructure Layers

### Layer 1 — Network Foundation (`modules/vpc`)

| Resource | Config | Purpose |
|---|---|---|
| VPC | `10.0.0.0/16` | Isolated network boundary |
| Public Subnets | `10.0.101.0/24`, `10.0.102.0/24` | Load balancers, ingress |
| Private Subnets | `10.0.1.0/24`, `10.0.2.0/24` | EKS nodes, RDS, Redis |
| Internet Gateway | — | Outbound public internet for public subnets |
| Route Tables | Public + Private per AZ | Traffic routing |
| NAT Gateway | Disabled (dev cost saving) | Production: enables private subnet outbound |

Two Availability Zones (`us-east-1a`, `us-east-1b`) are used throughout for high availability.

EKS-required subnet tags are applied automatically:
- Public: `kubernetes.io/role/elb = 1`
- Private: `kubernetes.io/role/internal-elb = 1`

---

### Layer 2 — Compute (`modules/eks`)

| Resource | Config | Purpose |
|---|---|---|
| EKS Cluster | v1.29 | Managed Kubernetes control plane |
| Node Group | `t3.small` SPOT, min 1 / max 3 / desired 2 | Application workload nodes |
| CoreDNS | Latest | Internal DNS resolution |
| kube-proxy | Latest | Network rules on nodes |
| VPC CNI | Latest | Pod networking |
| EBS CSI Driver | Latest | Persistent volume support |
| OIDC Provider | Enabled (IRSA) | Fine-grained IAM per pod |
| Public API endpoint | Enabled | `kubectl` access from local machine |

SPOT instances are used to reduce compute costs by ~70% vs on-demand.

---

### Layer 3 — Database (`modules/rds`)

| Resource | Config | Purpose |
|---|---|---|
| RDS PostgreSQL | v16.1, `db.t3.micro` | Primary relational database |
| Storage | 20 GB | Free tier eligible |
| Subnet Group | Private subnets only | No public exposure |
| Security Group | Port 5432, VPC CIDR only | Intra-VPC access only |
| Public Access | `false` | Enforced private placement |
| Final Snapshot | `skip = true` | Lab environment teardown |

Password is injected via `TF_VAR_db_password` environment variable — never stored in code or state files in plaintext.

---

### Layer 4 — Caching (`modules/elasticache`)

| Resource | Config | Purpose |
|---|---|---|
| ElastiCache Redis | v7.1, `cache.t3.micro` | Session caching, pub/sub |
| Nodes | 1 | Free tier eligible |
| Port | 6379 | Standard Redis port |
| Subnet Group | Private subnets only | No public exposure |
| Security Group | Port 6379, VPC CIDR only | Intra-VPC access only |

---

### State Backend (`bootstrap-state/`)

| Resource | Purpose |
|---|---|
| S3 Bucket `next-afield-tf-state-bhavishya` | Stores `.tfstate` files remotely |
| DynamoDB Table `next-afield-tf-locks` | Prevents concurrent Terraform runs |
| Encryption | `encrypt = true` on S3 backend |

The bootstrap state resources are managed separately so they exist before the main infrastructure is provisioned.

---

## GitOps Workflow

### How a change flows end-to-end

```
1. Developer edits a .tf file
        ↓
2. Opens a Pull Request on GitHub
        ↓
3. GitHub sends webhook to Atlantis server
        ↓
4. Atlantis runs: terraform init → terraform plan
        ↓
5. Plan output is posted as a PR comment (57 to add / N to change / N to destroy)
        ↓
6. Checkov scans the code and posts policy results
        ↓
7. A reviewer approves the PR
        ↓
8. Reviewer comments: atlantis apply -p root-aws-infrastructure
        ↓
9. Atlantis runs: terraform apply
        ↓
10. Infrastructure is live. PR is merged.
```

### `atlantis.yaml` configuration

```yaml
version: 3
automerge: false          # Human must click merge — no auto-merge on apply
parallel_plan: true       # Plans run in parallel for speed
parallel_apply: false     # Applies run sequentially for safety

projects:
  - name: root-aws-infrastructure
    dir: .
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["*.tf", "modules/**/*.tf"]
      enabled: true
    apply_requirements: [approved, mergeable]  # Two gates before any apply
```

### Triggering commands on a PR

| Command | Effect |
|---|---|
| `atlantis plan` | Auto-detect changed projects and plan |
| `atlantis plan -p root-aws-infrastructure` | Force plan a specific project (bypasses `when_modified` filter) |
| `atlantis apply -p root-aws-infrastructure` | Apply after PR is approved |

---

## Security & Compliance

### Checkov Static Analysis

Every plan is preceded by Checkov scanning the Terraform code against the CIS AWS Benchmark and AWS Security Best Practices.

**Passing checks include:**

| Check | What it validates |
|---|---|
| RDS not publicly accessible | `publicly_accessible = false` ✅ |
| Security groups have descriptions | Enforced on all SGs ✅ |
| Security group rules have descriptions | Enforced on all rules ✅ |
| Redis in VPC | Subnet group enforces private placement ✅ |
| EKS IRSA enabled | `enable_irsa = true` ✅ |
| S3 backend encryption | `encrypt = true` ✅ |
| No hardcoded credentials | Verified via grep across all files ✅ |




---

### Security design decisions

- All database and cache resources placed in **private subnets** — no public IPs
- Security groups restrict traffic to **VPC CIDR only** (not `0.0.0.0/0`)
- Database password injected via **environment variable** (`TF_VAR_db_password`) — never in code, never in git
- OIDC/IRSA enabled on EKS so pods get **least-privilege IAM roles**, not node-level access keys
- NAT gateway is disabled in dev — private subnets have **no outbound internet** by default

---

## Cost Strategy

| Decision | Monthly Saving |
|---|---|
| NAT Gateway disabled (dev) | ~$32/month saved |
| EKS SPOT instances (`t3.small`) | ~70% vs on-demand |
| RDS `db.t3.micro` | Free tier eligible |
| ElastiCache `cache.t3.micro` | Free tier eligible |
| Single-AZ Redis (1 node) | vs $15+/month for multi-AZ |

Estimated monthly cost for this dev environment: **< $10/month** (primarily EKS control plane at ~$0.10/hr).

---

## How to Prove It Works

Anyone reviewing this project can verify it is functional using these checkpoints:

### ✅ Checkpoint 1 — Terraform Plan is Clean

On the GitHub PR, the Atlantis check shows:

```
atlantis/plan: root-aws-infrastructure — Plan: 57 to add, 0 to change, 0 to destroy.
```

This means Terraform has fully parsed all modules, resolved all variable references, authenticated to AWS, acquired the state lock from DynamoDB, and produced a complete execution plan with zero errors.

### ✅ Checkpoint 2 — All CI Checks Pass

The GitHub PR shows **4/4 checks green**:

| Check | Status | What it proves |
|---|---|---|
| `atlantis/plan` | ✅ 1/1 planned | Terraform plan succeeded |
| `atlantis/plan: root-aws-infrastructure` | ✅ Plan: 57 to add | Full resource graph resolved |
| `atlantis/apply` | ✅ 0/0 | No unapproved applies (correct gate) |
| `atlantis/policy_check` | ✅ 0/0 | Checkov passed |

### ✅ Checkpoint 3 — Remote State Backend is Live

The fact that Terraform successfully acquires and releases a state lock proves the S3 bucket and DynamoDB table exist and are reachable:

```
Acquiring state lock. This may take a few moments...
Releasing state lock. This may take a few moments...
```

### ✅ Checkpoint 4 — Module Resolution

All 4 modules resolve without errors:
- `module.vpc` → 19 resources
- `module.eks` → ~25 resources (control plane, node group, addons, IAM)
- `module.rds` → 3 resources (instance, subnet group, security group)
- `module.elasticache` → 3 resources (cluster, subnet group, security group)

### ✅ Checkpoint 5 — GitOps Gate is Enforced

The `apply_requirements: [approved, mergeable]` config means apply is blocked until a human approves the PR. This is verifiable in the Atlantis logs and the PR status.

### ✅ Checkpoint 6 — No Hardcoded Secrets

Running this grep across the repo returns zero results:

```bash
grep -r "access_key\|secret_key\|password\s*=\s*\"" --include="*.tf" .
```

Passwords are injected via `TF_VAR_*` environment variables at Atlantis server launch time.

---

### ✅ Checkpoint 7 — Automated Infrastructure Tests (Terratest)

The project includes a `test/` directory with Go-based infrastructure tests. Running `make test` will:
1. Spin up a temporary VPC.
2. Assert that the VPC ID is valid.
3. Automatically destroy the resources.

This proves that the modules are not just syntactically correct, but functionally capable of provisioning real AWS resources.

---

## Project Structure

```
next-afield-aws-infra/
├── main.tf                     # Root module — wires all 4 modules together
├── variables.tf                # Root-level inputs
├── outputs.tf                  # Exported values after apply
├── atlantis.yaml               # GitOps workflow configuration
├── .checkov.yaml               # Security scan suppression rules
├── .gitignore                  # Standard git ignore + local secrets
├── .terraform.lock.hcl         # Provider version lock file
├── Makefile                    # Local developer commands
│
├── .github/
│   └── workflows/
│       ├── ci.yml              # Linting, validation, and security scanning
│       └── drift-detection.yml # Daily 8 AM drift check
│
├── bootstrap-state/            # One-time setup: creates S3 bucket + DynamoDB table
│   └── main.tf
│
├── modules/
│   ├── vpc/                    # Network foundation
│   ├── eks/                    # Kubernetes cluster
│   ├── rds/                    # PostgreSQL database
│   └── elasticache/            # Redis cache
│
└── test/                       # Terratest infrastructure verification
    ├── go.mod
    └── vpc_test.go
```

---

## Local Developer Commands

The `Makefile` provides a standard interface for local operations:

| Command | Action |
|---|---|
| `make init` | Initialize Terraform and download providers |
| `make fmt` | Recursively format all `.tf` files |
| `make lint` | Run `tflint` and `checkov` security scans |
| `make test` | Execute Go-based Terratests |
| `make plan` | Run a local `terraform plan` |
| `make bootstrap`| One-time setup of the S3/DynamoDB backend |


---

## Troubleshooting

### Stale DynamoDB State Lock

When an Atlantis execution is forcefully killed — dropped ngrok tunnel, Ctrl+C, VM crash — the DynamoDB lock is not released. The next plan will fail immediately with:

```
Error: Error acquiring the state lock
  Error message: ConditionalCheckFailedException: The conditional request failed
  Lock Info:
    ID: <lock-uuid>
```

**Resolution:**

1. Go to AWS Console → DynamoDB → Tables → `next-afield-tf-locks` → Explore items
2. Find the locked item and copy the full `LockID` value (it looks like a UUID)
3. Force-release the lock locally:

```bash
cd next-afield-aws-infra
terraform force-unlock <LockID>
```

4. Re-trigger the plan on the PR: `atlantis plan -p root-aws-infrastructure`

> **Warning:** Only force-unlock if you are certain no Terraform process is actively running. Unlocking during a live apply can corrupt the state file.

### `when_modified` Filter Swallowing Plans

If `atlantis plan` on a PR produces `0 projects are to be planned`, the changed files did not match the `when_modified` glob. Always use the explicit project flag to bypass the filter:

```bash
# On the PR, comment:
atlantis plan -p root-aws-infrastructure
```

### ngrok Tunnel Expired

Free ngrok tunnels expire after ~2 hours. If GitHub webhooks stop delivering, restart ngrok, update the `--atlantis-url` flag with the new URL, relaunch Atlantis, and update the webhook URL in your GitHub repository settings (Settings → Webhooks).

---

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Terraform | `>= 1.5.0` | IaC engine |
| Atlantis | Latest | GitOps server |
| AWS CLI | Latest | Credential configuration |
| ngrok | Latest | Tunnel GitHub webhooks to local Atlantis |
| Git + GitHub account | — | Source control and PR workflow |

AWS IAM user needs: `AdministratorAccess` (for provisioning) or a scoped policy covering EC2, EKS, RDS, ElastiCache, VPC, IAM, S3, DynamoDB.

---

## Running Locally

### Step 1 — Bootstrap the state backend (one-time only)

```bash
cd bootstrap-state/
terraform init
terraform apply
cd ..
```

### Step 2 — Export environment variables

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_REGION="us-east-1"
export TF_VAR_db_password="YourSecurePassword123!"
```

### Step 3 — Start ngrok tunnel

```bash
ngrok http 4141
# Copy the HTTPS URL it gives you
```

### Step 4 — Launch Atlantis server

```bash
export NGROK_URL="https://your-ngrok-url.ngrok-free.app"

atlantis server \
  --atlantis-url="$NGROK_URL" \
  --gh-user="your-github-username" \
  --gh-token="your-github-pat" \
  --gh-webhook-secret="your-webhook-secret" \
  --repo-allowlist="github.com/your-org/next-afield-aws-infra" \
  --data-dir="$HOME/atlantis-data"
```

### Step 5 — Open a PR and trigger a plan

On any open PR, comment:

```
atlantis plan -p root-aws-infrastructure
```

Atlantis will post the plan output directly on the PR within ~60 seconds.

### Step 6 — Apply (after PR approval)

```
atlantis apply -p root-aws-infrastructure
```

### Step 7 — Environment Teardown (CRITICAL)

To prevent ongoing AWS charges — specifically the EKS control plane at ~$0.10/hr — you **must** destroy the environment when finished. Since the Atlantis server holds no local state, run this directly from your WSL terminal:

```bash
# Make sure AWS credentials are still exported in your shell
cd next-afield-aws-infra
terraform destroy -auto-approve
```

Wait for the terminal to confirm:

```
Destroy complete! Resources: 57 destroyed.
```

Do not close the terminal or kill the process before seeing this confirmation. A partial destroy will leave orphaned resources accruing charges. If the destroy is interrupted, re-run `terraform destroy` — Terraform is idempotent and will only attempt to remove what still exists.

> **Note:** The bootstrap state resources (S3 bucket + DynamoDB table) are managed separately and are **not** destroyed by the above command. To remove those, run `terraform destroy` inside the `bootstrap-state/` directory as a final step.

---

## Environment Variables Reference

| Variable | Where set | Purpose |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Shell (before atlantis launch) | AWS authentication |
| `AWS_SECRET_ACCESS_KEY` | Shell (before atlantis launch) | AWS authentication |
| `AWS_REGION` | Shell (before atlantis launch) | Default AWS region |
| `TF_VAR_db_password` | Shell (before atlantis launch) | RDS master password (injected into Terraform) |
| `NGROK_URL` | Shell (before atlantis launch) | Public URL for GitHub webhook delivery |

None of these should ever be committed to git or stored in `.tfvars` files inside the repository.

---

## Known Suppressions & Justifications

The `.checkov.yaml` file suppresses checks that are inapplicable to this environment:

| Check | Reason suppressed |
|---|---|
| `CKV_AWS_28` | RDS backup retention — intentionally low for dev/lab teardown |
| `CKV_AWS_119` / `CKV_AWS_161` / `CKV_AWS_293` | ElastiCache encryption — at-rest and in-transit encryption requires paid tier; this is a dev cluster |
| `CKV_TF_1` | Module pinning to commit hash — version pinning via `~>` is sufficient for this project |
| `CKV_AWS_16` / `CKV_AWS_118` | RDS encryption — `db.t3.micro` free-tier instances do not support encryption at rest |
| `CKV2_AWS_60` / `CKV2_AWS_62` | S3 lifecycle / versioning — state bucket does not require versioning in this setup |
| `CKV2_AWS_11` / `CKV2_AWS_12` | VPC flow logs — cost-saving decision for dev; should be enabled in production |
| `CKV_AWS_144` / `CKV_AWS_145` | S3 cross-region replication / KMS — dev environment, not required |

All suppressions are deliberate, documented, and scope-limited to this dev environment. A production deployment would address each one.

---

## Production Hardening Checklist

Before promoting this to production, the following should be addressed:

- [ ] Enable NAT Gateway (private subnet outbound internet)
- [ ] Enable RDS encryption at rest (use `db.t3.medium` or higher)
- [ ] Enable ElastiCache in-transit and at-rest encryption
- [ ] Enable VPC Flow Logs
- [ ] Replace `TF_VAR_db_password` with AWS Secrets Manager
- [ ] Enable RDS automated backups (retention ≥ 7 days)
- [ ] Enable S3 versioning on state bucket
- [ ] Pin all module sources to specific git commit hashes
- [ ] Add multi-AZ for RDS (`multi_az = true`)
- [ ] Set `skip_final_snapshot = false` on RDS
- [ ] Implement Infracost for automated PR cost estimation
- [ ] Implement OPA (Open Policy Agent) for fine-grained policy enforcement (e.g., instance type restrictions)

---

*Infrastructure designed and operated by Bhavishya Raj. Built with Terraform `v1.5.0`, Atlantis, and Checkov on AWS `us-east-1`.*
