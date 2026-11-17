# Kế hoạch B: CI/CD Security

Phụ trách B: Git governance, GitHub Actions, security gates, ArgoCD, Kyverno, NetworkPolicy.

---

## Giai đoạn 1: Nền móng Git

Thiết lập quy trình làm việc cho repo trước khi bất kỳ tính năng nào bắt đầu. Bao gồm `.gitignore` cho Python/Terraform/secrets, `CONTRIBUTING.md` với branch naming và Conventional Commits, `CODEOWNERS` map thư mục sang vai, PR template (What/Why/Verify), issue templates, CI skeleton với lint + test + build image. Actions được ghim theo SHA đầy đủ để tránh supply chain attack.

**Xác nhận xong:** push thẳng lên `main` bị từ chối bởi branch protection; PR không có approval không merge được; CI chạy và có màu xanh/đỏ rõ ràng.

---

## Giai đoạn 2: CI Security Pipeline

Thêm 3 security gate chạy song song vào `ci-pr.yml`:

**Gitleaks:** quét toàn bộ git history với `fetch-depth: 0`. Phát hiện API key, token, password theo regex pattern. Fail khi tìm thấy bất kỳ secret nào.

**Semgrep:** SAST với ruleset `p/default`. Phát hiện các lỗi bảo mật phổ biến trong Python. Fail khi có finding mức HIGH trở lên.

**Trivy:** hai scan tách biệt: `fs` quét dependency (`app/requirements.txt`), `config` quét IaC (Terraform, Helm, Dockerfile). Fail với HIGH/CRITICAL, bật `ignore-unfixed` để không block bởi CVE chưa có bản vá.

Tạo `cd-main.yml` chạy khi merge vào `main`: build image → Trivy scan image (CRITICAL only) → push GHCR với tag SHA. Tag SHA là bất biến, là cơ sở để ArgoCD trỏ đúng version.

**Xác nhận xong:** commit chứa API key giả làm CI đỏ tại Gitleaks; dependency có CVE nghiêm trọng làm CI đỏ tại Trivy; image xuất hiện trên GHCR với tag SHA sau khi merge.

---

## Giai đoạn 3: GitOps

Thiết lập cấu trúc repo `gitops` và vòng lặp tự động từ commit đến cluster.

Repo `gitops` có cấu trúc: `helm/sentraops/` (chart), `dev/values.yaml` (image tag, pipeline tự bump), `staging/values.yaml`, `prod/values.yaml`, `apps/sentraops-dev.yaml` (ArgoCD Application manifest).

ArgoCD Application cho `dev` với `automated.prune: true` và `selfHeal: true` sẽ tự xóa resource không còn trong Git và tự khôi phục nếu ai sửa tay trên cluster. Đây là cơ sở của kịch bản demo rollback.

Bổ sung job `bump-gitops` vào cuối `cd-main.yml`: clone gitops repo bằng fine-grained PAT, `sed` cập nhật `image.tag` trong `dev/values.yaml`, commit và push. ArgoCD phát hiện commit mới trong 3 phút và sync tự động.

**Xác nhận xong:** merge một thay đổi vào app repo, vài phút sau pod ở `dev` chạy đúng tag mới mà không ai chạm vào cluster.

---

## Giai đoạn 4: ArgoCD Install

Cài ArgoCD lên k3s cluster, expose qua NodePort, apply ArgoCD Application manifest từ gitops repo. Đây là điểm hội tụ của toàn bộ pipeline; sau bước này, lát cắt dọc từ commit đến cluster hoàn chỉnh.

**Xác nhận xong:** `curl http://<EC2-IP>:30080/health` trả `{"status":"ok"}` sau khi merge một commit vào app repo.

---

## Giai đoạn 5: Cluster Security

**Kyverno:** cài qua Helm, tạo 2 policy. Policy 1: `disallow-root-container` cấm container chạy với `runAsUser: 0` hoặc không có `runAsNonRoot: true`. Policy 2: `restrict-registry` chỉ cho phép image từ `ghcr.io/hwuxfuoc/*`. Chạy Audit mode trước, xem violation report, chuyển sang Enforce sau khi đã xác nhận không có false positive làm hỏng hệ thống.

**NetworkPolicy:** default-deny cho tất cả namespace, sau đó mở từng rule cụ thể: gateway → app service, gateway → Chroma service, DNS egress. Chặn egress của model server ra Internet (Ollama cần tải model trước khi đóng egress).

**Xác nhận xong:** `kubectl apply` một pod chạy root từ registry lạ bị Kyverno từ chối với message rõ ràng; thử curl từ namespace khác sang app bị NetworkPolicy block.

---

## Giai đoạn 6: Supply Chain và Prod Gate

**ModelScan:** thêm job vào `cd-main.yml` trước bước push GHCR. Quét model artifact pickle để phát hiện serialization attack. Lưu ý: ModelScan không hỗ trợ GGUF, nên dùng file pickle mẫu từ test suite của ModelScan để demo kịch bản 4.

**GitHub Environments:** tạo environment `staging` và `prod` trên GitHub, thêm required reviewers, thêm deployment protection rules. Các job deploy staging/prod trong `cd-main.yml` khai báo `environment:` tương ứng; GitHub tự dừng và chờ approval trước khi chạy tiếp.

**Xác nhận xong:** push model pickle độc hại khiến pipeline fail tại ModelScan; job deploy-prod dừng và hiện nút "Review deployments" trên GitHub.

---

## Giai đoạn 7: LLM Gate trong CI

Thêm job `promptfoo-smoke` vào `cd-main.yml` chạy sau bước deploy dev. Job gọi ~10 prompt từ bộ test của Vai C vào endpoint dev, fail nếu ASR vượt ngưỡng do nhóm thống nhất. C cung cấp danh sách prompt và threshold, B tích hợp vào pipeline.

**Xác nhận xong:** vòng lặp Develop → Scan → Red-team → Deploy chạy end-to-end từ một commit duy nhất.

---

## Danh sách bàn giao

- Hai repo với branch protection, CODEOWNERS, templates
- `ci-pr.yml` với 4 gate: lint+test, Gitleaks, Semgrep, Trivy
- `cd-main.yml` với: build, Trivy image, ModelScan, push GHCR, bump gitops, deploy environments, promptfoo smoke
- Kyverno policies và NetworkPolicy manifests trong gitops repo
- Bằng chứng kịch bản 3 và 4 (ảnh + log)
