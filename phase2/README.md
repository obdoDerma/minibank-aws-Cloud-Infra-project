# MiniBank on AWS – Phase 2: Production-ready (runbook)

## 1. Full picture
**Starting point:** Phase 1 has been destroyed, so nothing is running. Phase 2 is a complete stack: everything from Phase 1 plus the upgrades.

| Change vs Phase 1 | Phase 1 | Phase 2 |
|---|---|---|
| Entry point | EC2 public IP | **Application Load Balancer** (only public component) |
| Web servers | 1 server, public subnet | **2–4 servers, Auto Scaling, private subnets, no public IP** |
| Self-healing | none | Failed health check → server replaced automatically |
| Scaling | none | Target-tracking: keep average CPU ~50% |
| Package installs | via internet gateway | via **free S3 gateway endpoint** (no NAT gateway) |
| Database | single AZ | **Multi-AZ** standby with automatic failover |
| Monitoring | basic metrics | **CloudWatch alarms → SNS email** |
| Terraform state | laptop file | **S3 bucket**, versioned, encrypted, with locking |
| Shell access | SSM over internet | Off by default (immutable servers); switch on with `enable_ssm_endpoints = true` |

**Subnets:** public `10.0.1-2.0/24` (ALB) · app `10.0.21-22.0/24` (servers) · db `10.0.11-12.0/24` (RDS).
**Security group chain:** internet →80→ `alb-sg` →80→ `app-sg` →3306→ `db-sg`.

## 2. Cost
| Item | ~ per hour |
|---|---|
| ALB + its 2 public IPs | $0.045 |
| 2 × EC2 t3.micro | $0.024 |
| RDS db.t3.micro Multi-AZ | $0.040 |
| **Total** | **≈ $0.11/hour → 2-hour session ≈ $0.25** |

The state bucket (bootstrap) stays between sessions and costs a few cents a month.
Cheaper quick session: set `db_multi_az = false` in tfvars (saves ~$0.02/hour, but no failover test).

## 3. Order of work
| Step | Folder | One time? |
|---|---|---|
| A. Bootstrap the state bucket | `bootstrap` | **once** for the whole project |
| B. Init Phase 2 with the S3 backend | `phase2` | once (again only if backend.hcl changes) |
| C. plan → apply | `phase2` | every session |
| D. Tests + screenshots | `phase2` | every session |
| E. Your task: CPU alarm | `phase2/monitoring.tf` | once |
| F. destroy | `phase2` | **every session** |

### A. Bootstrap (once)
```
cd B:\AWS-mini\bootstrap
terraform init
terraform apply          # type yes  -> creates the bucket + writes ..\phase2\backend.hcl
```

### B + C. Phase 2
```
cd B:\AWS-mini\phase2
Copy-Item terraform.tfvars.example terraform.tfvars   # then put your email in it
terraform init "-backend-config=backend.hcl"
terraform validate
terraform plan "-out=phase2.plan"
terraform apply "phase2.plan"
```
Apply takes **~20–25 min** (Multi-AZ RDS is slow; the servers wait for the DB).
📸 #8 plan summary · 📸 #9 apply complete + outputs (blur the account ID).

**After apply:** check your email for **"AWS Notification – Subscription Confirmation"** and click **Confirm subscription**, otherwise alarms never reach you.

## 4. Tests (yes/no)
| # | Test | How | Expected |
|---|---|---|---|
| 1 | Site via ALB | open `app_url` (wait ~3 min after apply) | "MiniBank – Phase 2" status page 📸 #10 |
| 2 | Load balancing | refresh 5–6 times | Instance ID / AZ changes between 2 servers |
| 3 | Private chain works | read the status table | `S3 … OK` and `Database reachable on 3306` |
| 4 | Servers are private | `aws ec2 describe-instances --filters "Name=tag:Name,Values=minibank-app" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].[InstanceId,PublicIpAddress]" --output table` | PublicIpAddress = **None** |
| 5 | Self-healing | run `list_servers_command` from outputs → copy one ID → `aws ec2 terminate-instances --instance-ids <id>` → keep refreshing the site → after 2–4 min run `list_servers_command` again | Site stays up on the other server; a **new** instance ID appears 📸 #11 |
| 6 | Alarm email | after test 5 | "ALARM: minibank-unhealthy-hosts" email, then "OK" |
| 7 | DB failover | `aws rds describe-db-instances --db-instance-identifier minibank-db --query "DBInstances[0].[AvailabilityZone,SecondaryAvailabilityZone]"` → `aws rds reboot-db-instance --db-instance-identifier minibank-db --force-failover` → wait ~3 min → run the describe again | The two AZs **swap**; the endpoint name stays the same 📸 #12 |
| 8 | State in S3 | `aws s3 ls s3://<state bucket>/phase2/` (bucket name is in `backend.hcl`) | `terraform.tfstate` listed |

## 5. Your task: CPU alarm
Open `monitoring.tf` and follow the YOUR TASK block. Then `terraform fmt` → `validate` → `plan` (expect **1 to add**) → `apply`. Send the plan to Claude for review.

## 6. Destroy (end of every session)
```
cd B:\AWS-mini\phase2
terraform destroy        # type yes, ~10 min
```
📸 #13 "Destroy complete". **Do NOT destroy `bootstrap`** — it holds the state for future sessions. Destroy it only when the whole project ends.

## 7. Rollback / troubleshooting
| Problem | Fix |
|---|---|
| `init` error about backend | `backend.hcl` missing → run step A first; check the file exists in `phase2` |
| Site shows 502/503 | servers still booting (wait 3–5 min); check `list_servers_command` → HealthStatus |
| Status page says "python3 fallback" | dnf couldn't reach the repos → S3 endpoint/route problem; the site still works |
| Need a shell on a server | set `enable_ssm_endpoints = true` in tfvars → plan → apply → `aws ssm start-session --target <id>` |
| Apply fails halfway | fix the error, run plan + apply again; Terraform continues |
| "state lock" error | another run is active or crashed; wait, then if sure: `terraform force-unlock <LOCK_ID>` |

## 8. Risks
- Forgetting `destroy` ≈ $2.60/day. The $3 budget alert is your safety net.
- Terminating servers or forcing failover is safe here **only** because this is a lab.
- Never edit or delete the state file in S3 by hand.

## 9. Interview talking points
- "Only the load balancer is public. Servers are private with no internet route; they reach S3 through a gateway endpoint, which saved a NAT gateway."
- "Security groups chain by identity: ALB → app → DB, so scaling never breaks the rules."
- "I proved self-healing by terminating a server under traffic, and proved Multi-AZ by forcing a DB failover — the endpoint stayed the same."
- "State lives in a versioned, encrypted S3 bucket with locking, like a team setup."
