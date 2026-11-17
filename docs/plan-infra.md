# Kế hoạch A: Infra & App

Phụ trách A: Terraform, k3s, Helm, FastAPI + RAG + Ollama + Chroma, tích hợp tổng thể.

---

## Giai đoạn 1: Hạ tầng

Viết Terraform IaC để provision EC2 trên AWS ap-northeast-1. Cấu trúc: `main.tf` (EC2 + Elastic IP, data source AMI Ubuntu để không hardcode AMI ID), `network.tf` (security group mở port 22/6443/30080/30443), `variables.tf`, `outputs.tf`, `user_data.sh` (tự cài k3s và cấu hình kubeconfig khi EC2 khởi động), `terraform.tfvars.example` (template, không commit file thật).

Elastic IP giữ IP cố định sau khi restart nên ArgoCD và kubeconfig không bị hỏng. Swap 2GB trong `user_data.sh` bù cho RAM 1GB của t2.micro (k3s + ArgoCD + app cần ~1.5GB).

Terraform là cơ sở của kịch bản demo 1: `terraform destroy && terraform apply` dựng lại toàn bộ từ 0 mà không cần can thiệp thủ công.

**Xác nhận xong:** `terraform apply` tạo EC2, SSH vào được, `kubectl get nodes` trả `Ready`.

---

## Giai đoạn 2: Ứng dụng local

Xây dựng stack ứng dụng chạy được trên máy local trước khi containerize. FastAPI gateway nhận request, gọi ChromaDB để retrieve context, gọi Ollama để generate response. `docker-compose.yml` khởi động 3 service: FastAPI, Chroma, Ollama.

Pull model Qwen2.5:0.5b (nhỏ nhất, chạy được trên CPU): `docker exec ollama ollama pull qwen2.5:0.5b`. Model 0.5B phù hợp cho demo vì inference đủ nhanh, không cần GPU.

**Xác nhận xong:** `curl http://localhost:8000/chat` trả response từ LLM có dùng context từ ChromaDB.

---

## Giai đoạn 3: Containerization

Viết Helm chart tại `helm/sentraops/`: `Chart.yaml`, `values.yaml` (image repository, tag, service NodePort 30080, resource limits), `templates/deployment.yaml` (securityContext non-root, liveness/readiness probe trỏ `/health`, resource limits bắt buộc trên t2.micro), `templates/service.yaml` (NodePort).

securityContext non-root là bắt buộc vì Kyverno (B) sẽ enforce policy này ở giai đoạn sau. Nếu Deployment không có `runAsNonRoot: true`, Kyverno Enforce mode sẽ từ chối deploy.

Cập nhật Dockerfile để mirror securityContext: tạo non-root user, `USER appuser` trước `CMD`.

Chart này được copy vào `gitops/helm/sentraops/`; ArgoCD đọc chart từ gitops repo và override `image.tag` từ `dev/values.yaml`.

**Xác nhận xong:** `helm template` render manifest hợp lệ; image build và push lên GHCR được.

---

## Giai đoạn 4: Deploy lên cluster và môi trường

Cập nhật values cho từng môi trường trong gitops repo: `dev/values.yaml` (resource limits nhỏ, replica 1), `staging/values.yaml` (tương tự prod về cấu hình nhưng data test), `prod/values.yaml` (resource limits cao hơn).

Tạo ArgoCD Application riêng cho staging và prod với `automated: {}` bỏ trống (manual sync). Phối hợp với B để staging/prod đi qua GitHub Environments approval gate.

Thêm health check endpoint `/health` trả `{"status":"ok"}`; k8s dùng cho readiness/liveness probe, CI smoke test sau deploy dùng endpoint này.

**Xác nhận xong:** app chạy ổn định trên cả 3 namespace, health check pass, resource không vượt limit.

---

## Giai đoạn 5: Tích hợp

Mount `GuardrailMiddleware` từ `app/guardrail.py` (C viết) vào `app/main.py`. Thêm `prometheus-fastapi-instrumentator` để expose `/metrics`. Phối hợp với C để kiểm tra metrics hiển thị đúng trên Prometheus.

Hỗ trợ kịch bản demo 2 (rollback): thử `git revert` trong gitops repo, ArgoCD tự sync về SHA cũ.

---

## Danh sách bàn giao

- Terraform code đủ để demo `destroy && apply`
- FastAPI app với RAG (Chroma) và Ollama integration
- Helm chart với securityContext đúng chuẩn Kyverno
- `docker-compose.yml` cho local dev
- App chạy ổn định trên 3 namespace (dev/staging/prod)
