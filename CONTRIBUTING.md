# Contributing to SentraOps

## Branch

- `main` là branch chính — không push thẳng, mọi thay đổi qua Pull Request.
- Tạo branch từ `main` mới nhất trước khi bắt đầu công việc.
- Đặt tên: `<type>/<mô-tả-ngắn>` — tiếng Anh, chữ thường, dùng `-`.

| Type | Dùng khi |
| --- | --- |
| `feat` | Thêm tính năng mới |
| `fix` | Sửa bug |
| `ci` | Thay đổi CI/CD workflow |
| `docs` | Cập nhật tài liệu |
| `refactor` | Tái cấu trúc code, không thêm tính năng |
| `test` | Thêm hoặc sửa test |
| `chore` | Cập nhật cấu hình, dependency |

Ví dụ: `feat/rag-chroma`, `ci/add-trivy-scan`, `fix/health-endpoint`.

```sh
git switch main
git pull --ff-only origin main
git switch -c feat/ten-cong-viec
# Thực hiện thay đổi, commit, rồi push.
git push -u origin feat/ten-cong-viec
```

## Commit

Dùng [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <mô tả ngắn bằng tiếng Anh>
```

Ví dụ:
- `feat: add RAG endpoint with Chroma`
- `ci: add Gitleaks secret scanning`
- `fix: correct health check path`

Quy tắc:
- Dùng thì hiện tại, không viết hoa chữ đầu sau dấu `:`
- Không chấm cuối
- Tối đa 72 ký tự

## Pull Request

- Mở PR từ feature branch vào `main`.
- Điền đủ 3 mục trong template: **What**, **Why**, **Verify**.
- Giữ mỗi PR tập trung vào một công việc.
- PR cần ít nhất 1 approval và tất cả status check xanh trước khi merge.

## Ownership

Xem [CODEOWNERS](.github/CODEOWNERS) để biết ai review phần nào.
