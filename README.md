# SentraOps: App Repo

DevSecOps & LLMOps pipeline cho ứng dụng Gen-AI RAG trên Kubernetes.

---

## Kiến trúc tổng quan

```
Developer
    │  git push → feature branch
    ▼
GitHub (repo này)
    ├── Pull Request → ci-pr.yml
    │       ├── Lint & Test (ruff, pytest)
    │       ├── Secret scan (Gitleaks)
    │       ├── SAST (Semgrep)
    │       └── Dependency + IaC scan (Trivy)
    │
    └── Merge to main → cd-main.yml
            ├── Build Docker image
            ├── Trivy image scan
            ├── ModelScan (model artifact)
            ├── Push → GHCR: ghcr.io/hwuxfuoc/sentraops-app:<SHA>
            └── Bump image tag trong gitops repo

GitHub (NT548_SentraOps_gitops)
    │  ArgoCD polls every 3 min
    ▼
k3s cluster (EC2 52.68.23.160)
    ├── namespace sentraops-dev    ← auto-sync
    ├── namespace sentraops-staging ← manual sync
    └── namespace sentraops-prod   ← manual approval
```

---

## Stack

| Nhóm | Công cụ |
|---|---|
| Ứng dụng | FastAPI, ChromaDB, Ollama (Qwen2.5) |
| Hạ tầng | Terraform, k3s, Helm |
| CI/CD | GitHub Actions, Gitleaks, Semgrep, Trivy, ModelScan |
| GitOps | ArgoCD |
| Cluster security | Kyverno, NetworkPolicy |
| LLM Security | promptfoo, guardrail middleware |
| Monitoring | Prometheus, Grafana |

---

## Cấu trúc repo

```
NT548_SentraOps_app/
├── app/                  ← FastAPI application code
│   ├── main.py
│   ├── rag.py            (thêm sau)
│   ├── guardrail.py      (thêm sau, Vai C)
│   └── requirements.txt
├── tests/                ← pytest test suite
├── helm/sentraops/       ← Helm chart (thêm sau, Vai A)
├── terraform/            ← IaC cho EC2 k3s (thêm sau, Vai A)
├── redteam/              ← promptfoo test suite (thêm sau, Vai C)
├── monitoring/           ← Prometheus/Grafana config (thêm sau, Vai C)
├── .github/
│   ├── workflows/
│   │   ├── ci-pr.yml     ← CI chạy khi mở PR
│   │   └── cd-main.yml   ← CD chạy khi merge vào main (thêm sau)
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
├── Dockerfile
├── pytest.ini
├── CONTRIBUTING.md
└── README.md
```

---

## Team

| Vai | Người | Phụ trách |
|---|---|---|
| A: Infra & App | Nhân | Terraform, k3s, Helm, FastAPI + RAG + Ollama |
| B: CI/CD Security | Phước | GitHub Actions, security gates, ArgoCD, Kyverno, NetworkPolicy |
| C: LLM Security & Monitoring | Đồng | promptfoo, guardrail, Prometheus, Grafana |

---

## Cài đặt local

**Yêu cầu:** Python 3.11+, Docker, Docker Compose

```bash
# Clone repo
git clone https://github.com/hwuxfuoc/NT548_SentraOps_app.git
cd NT548_SentraOps_app

# Cài dependencies
pip install -r app/requirements.txt

# Chạy test
pytest tests/ -v

# Chạy app local
uvicorn app.main:app --reload --port 8000
# Truy cập: http://localhost:8000/health
```

Khi có `docker-compose.yml` (thêm ở Infra-part3):

```bash
docker compose up -d
```

---

## Pipeline CI/CD

**CI (ci-pr.yml):** chạy khi mở hoặc update Pull Request:
- Lint với `ruff`, unit test với `pytest`
- Secret scan: Gitleaks quét toàn bộ git history
- SAST: Semgrep với ruleset `p/default`
- Dependency scan: Trivy quét `app/requirements.txt`
- IaC scan: Trivy quét `terraform/` và `helm/`

**CD (cd-main.yml):** chạy khi merge vào `main`:
- Build Docker image, tag bằng commit SHA
- Trivy scan image
- ModelScan kiểm tra model artifact
- Push lên GHCR: `ghcr.io/hwuxfuoc/sentraops-app:<SHA>`
- Tự cập nhật image tag trong repo gitops → ArgoCD sync vào dev

---

## Branch protection

Nhánh `main` được bảo vệ:
- Mọi thay đổi phải qua Pull Request
- Cần ít nhất 1 approval
- CI pipeline phải xanh hết trước khi merge
- Không cho phép force push

Xem hướng dẫn đóng góp đầy đủ tại [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Repo liên quan

- [NT548_SentraOps_gitops](https://github.com/hwuxfuoc/NT548_SentraOps_gitops): GitOps manifests, ArgoCD đọc từ đây để deploy lên cluster
