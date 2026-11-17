# SentraOps: Tổng quan dự án

DevSecOps & LLMOps pipeline cho ứng dụng Gen-AI RAG trên Kubernetes.

---

## Bài toán

Ứng dụng chatbot RAG kết hợp nhiều lớp: LLM inference (Ollama), vector store (Chroma), gateway (FastAPI), tất cả chạy trên Kubernetes. Mỗi lớp mang theo attack surface riêng mà quy trình DevOps truyền thống không bao phủ. Gitleaks và Trivy bảo vệ tốt lớp code và dependency, nhưng không phát hiện prompt injection hay model artifact bị can thiệp. Kyverno và NetworkPolicy siết chặt cluster, nhưng không hiểu ngữ nghĩa của câu trả lời LLM.

Luận điểm của dự án: **đo được mức giảm rủi ro tại từng lớp bảo vệ, kèm chi phí (false positive rate, latency overhead), và trình bày rõ những gì vẫn lọt qua.** Mỗi layer có ít nhất một ca vi phạm thực tế được chứng minh bị chặn.

---

## Kiến trúc hệ thống

```
Developer
    │  git push → feature branch
    ▼
GitHub (NT548_SentraOps_app)
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
k3s cluster (EC2 ap-northeast-1)
    ├── namespace sentraops-dev    ← auto-sync
    ├── namespace sentraops-staging ← manual sync
    └── namespace sentraops-prod   ← manual approval gate
    │
    ├── Kyverno (admission controller)
    │     ├── disallow-root-container
    │     └── restrict-registry (ghcr.io/hwuxfuoc/* only)
    └── NetworkPolicy
          ├── default-deny per namespace
          ├── allow: gateway → app, gateway → chroma
          └── allow: DNS egress

Monitoring (namespace: monitoring)
    ├── Prometheus: scrape /metrics từ gateway
    └── Grafana: dashboard + alert (guardrail spike)

LLM Security (post-deploy)
    ├── promptfoo smoke (~10 prompt, chạy trong CI sau deploy dev)
    └── guardrail middleware (regex PII + heuristic injection)
```

---

## Stack công cụ

| Nhóm | Công cụ | Lý do chọn |
|---|---|---|
| Ứng dụng | FastAPI + ChromaDB + Ollama (Qwen2.5) | Async, dễ thêm middleware; embedded vector store; model nhỏ chạy được trên CPU |
| Hạ tầng | Terraform + k3s + Helm | IaC cho demo "dựng lại từ 0"; k3s nhẹ hơn kubeadm, có sẵn CNI; Helm render values theo môi trường |
| CI/CD | GitHub Actions + Gitleaks + Semgrep + Trivy + ModelScan | Actions tích hợp sẵn; Trivy quét 3 lớp với 1 công cụ; ModelScan kiểm tra integrity model |
| GitOps | ArgoCD | UI tốt cho demo, self-heal tự động |
| Cluster security | Kyverno + NetworkPolicy | Policy YAML đơn giản hơn OPA/Gatekeeper; NetworkPolicy là spec chuẩn k8s |
| LLM Security | promptfoo + guardrail | Framework test theo OWASP LLM Top 10; guardrail tự viết kiểm soát I/O |
| Monitoring | Prometheus + Grafana | Chuẩn de facto; Prometheus scrape `/metrics`, Grafana vẽ dashboard và fire alert |

---

## Phân vai và hợp đồng giao diện

| Vai | Phụ trách |
|---|---|
| **A** | Terraform, k3s, Helm, FastAPI + RAG + Ollama + Chroma, tích hợp tổng thể |
| **B** | Git governance, GitHub Actions, security gates, ArgoCD, Kyverno, NetworkPolicy |
| **C** | promptfoo, guardrail middleware, Prometheus, Grafana, alert rules |

**Hợp đồng giao diện:**

A giao cho B: đường dẫn Helm chart (`helm/sentraops/`), endpoint `/health` trả `{"status":"ok"}`, Dockerfile ở repo root. B không chờ app thật; dùng FastAPI placeholder từ giai đoạn đầu để CI không bị block.

A giao cho C: gateway có middleware hook tại `app/guardrail.py` (C viết, A mount vào), endpoint `/metrics` expose Prometheus metrics.

B giao cho cả nhóm: pipeline `ci-pr.yml` và `cd-main.yml` chạy job của A và C như job độc lập. Ai làm hỏng gate nào thì người đó sửa.

---

## Sáu kịch bản demo

**Kịch bản 1: Dựng lại từ số 0 (A):** `terraform destroy` xóa toàn bộ EC2, sau đó `terraform apply` tạo lại, k3s tự cài qua user_data, ArgoCD deploy app. Chứng minh toàn bộ hạ tầng là code, không có snowflake server.

**Kịch bản 2: Sự cố và rollback (A):** Push image lỗi, ArgoCD sync và pod crashloop. Thực hiện `git revert` trong gitops repo để rollback tag về SHA trước. Đo thời gian từ revert đến pod healthy. Phần 2: sửa tay deployment trên cluster, ArgoCD phát hiện drift và self-heal.

**Kịch bản 3: PR bị chặn (B):** Tạo PR chứa API key giả và dependency có CVE nghiêm trọng. CI pipeline đỏ tại Gitleaks và Trivy, PR không merge được.

**Kịch bản 4: Chặn chuỗi cung ứng hai lớp (B):** Lớp 1: image CVE CRITICAL hoặc pickle độc hại khiến pipeline fail tại Trivy/ModelScan. Lớp 2: `kubectl apply` pod chạy root hoặc từ registry lạ bị Kyverno từ chối.

**Kịch bản 5: Guardrail trước/sau (C):** Chạy ~40 prompt tấn công trên app không có guardrail, đo ASR. Bật guardrail, chạy lại, so sánh ASR, false positive rate, latency overhead. Nêu rõ những gì vẫn lọt qua.

**Kịch bản 6: Cảnh báo thời gian thực (C):** Spam 50 prompt injection trong 1 phút. Prometheus metric spike, Grafana alert fire. Đưa prompt đó vào bộ test hồi quy.

---

## Thứ tự thực hiện

Các part được nhóm theo làn; trong cùng một làn, tất cả task có thể chạy song song.

| Làn | Tasks | Ghi chú |
|---|---|---|
| **0** | B-part1 · A-part1 · C-part1 | Khởi động, độc lập hoàn toàn |
| **1** | B-part2 · A-part2 · A-part3 · C-part2 | Sau làn 0 |
| **2** | B-part3 · C-part3 | B-part3 cần B-part2+A-part2; C-part3 cần C-part2 |
| **3** | B-part4 | Mốc quan trọng: lát cắt dọc end-to-end |
| **4** | B-part5 · B-part6 · A-part4 · C-part4 | Cần cluster đang chạy |
| **5** | B-part7 · C-part5 · C-part6 | B-part7 cần threshold từ C |
| **6** | Thu thập bằng chứng (cả 3 vai) | Chạy kịch bản từ trạng thái sạch |

**Điểm tích hợp cần chú ý:**
- B-part7 cần C cung cấp threshold ASR trước khi tích hợp vào CI
- C-part3 cần A mount `GuardrailMiddleware` vào `app/main.py`
- C-part4 cần A expose `/metrics` từ gateway
- Kyverno Enforce mode chỉ bật sau khi A-part4 xong để không block deployment mới

---

## Ngoài phạm vi

Không fine-tune model, không production thật, không GKE/EKS/AKS, không canary deployment tự động, không OpenTelemetry, không Ansible, không SBOM. Các giới hạn này có chủ đích để giữ scope khả thi và tập trung vào các lớp bảo mật có thể đo lường được.
