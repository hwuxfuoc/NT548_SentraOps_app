# Contributing Guide

## Branch naming

Tất cả công việc làm trên feature branch, không push thẳng lên `main`.

Format: `<type>/<mô-tả-ngắn>` — dùng tiếng Anh, kebab-case.

| Type | Dùng khi |
|---|---|
| `feat/` | thêm tính năng mới |
| `fix/` | sửa bug |
| `ci/` | thay đổi pipeline hoặc workflow |
| `chore/` | cấu hình, dependency, non-code |
| `docs/` | tài liệu |
| `infra/` | Terraform, k3s, hạ tầng |
| `llm/` | LLM security, guardrail, test suite |

Ví dụ: `ci/add-trivy-scan`, `feat/rag-chroma-integration`, `fix/dockerfile-nonroot`

## Commit format

Dùng [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <mô tả ngắn>

[body tùy chọn]
```

Ví dụ:
- `feat(rag): add ChromaDB query with top-k retrieval`
- `ci: pin action SHAs for supply chain security`
- `fix(helm): add runAsNonRoot securityContext`

## Quy trình PR

1. Push branch lên remote: `git push -u origin <branch>`
2. Mở PR trên GitHub, điền đầy đủ 3 mục trong template (What / Why / Verify)
3. Chờ CI pipeline xanh hết
4. Chờ ít nhất 1 approval từ reviewer (CODEOWNERS tự động assign)
5. Merge bằng "Squash and merge" hoặc "Merge commit" — không dùng rebase merge
