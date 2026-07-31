# Phase 2A - Membership và cách ly Workspace

## Mục tiêu

Phase này tạo nền tảng phân quyền cho ứng dụng nhiều người dùng:

- Một `User` có thể tham gia nhiều `Workspace`.
- Một `Workspace` có nhiều `User` thông qua `Membership`.
- Mỗi membership giữ một trong ba vai trò: `owner`, `admin`, `member`.
- Người dùng chỉ truy vấn được workspace mà họ là thành viên.

Màn hình thêm, đổi vai trò và xóa thành viên được mô tả trong
`docs/PHASE_2_MEMBER_MANAGEMENT.md`.

## Mô hình dữ liệu

```text
User 1 --- n Membership n --- 1 Workspace
                  |
                  +--- role: owner | admin | member
```

Database bảo vệ các quy tắc sau:

1. `user_id` và `workspace_id` luôn tồn tại và có foreign key.
2. Một user không thể có hai membership trong cùng workspace.
3. Một workspace không thể có nhiều hơn một Owner.
4. Role ngoài `owner`, `admin`, `member` bị check constraint từ chối.

## Quyền hiện tại

| Hành động | Owner | Admin | Member | Người ngoài |
|---|---:|---:|---:|---:|
| Xem workspace | Có | Có | Có | Không |
| Sửa workspace | Có | Có | Không | Không |
| Xóa workspace | Có | Không | Không | Không |

Người ngoài workspace nhận `404` vì record không xuất hiện trong policy scope.
Thành viên có workspace nhưng thiếu quyền thực hiện hành động nhận `403`.

## Luồng tạo Workspace

Controller không tự lưu từng record. `Workspaces::Create` thực hiện một transaction:

1. Kiểm tra workspace hợp lệ.
2. Lưu workspace.
3. Tạo membership `owner` cho người tạo.
4. Nếu một bước thất bại, toàn bộ transaction được rollback.

Nhờ vậy không có trường hợp request thành công nhưng workspace mới lại thiếu Owner.

## Current.workspace

Khi mở một workspace, controller chỉ tìm record trong `policy_scope(Workspace)`.
Record tìm được được gán vào `Current.workspace` để các chức năng tài liệu và RAG sau
này luôn có ranh giới workspace rõ ràng.

Không dùng:

```ruby
Workspace.find(params[:id])
```

Luôn dùng policy scope hoặc association bắt đầu từ user/workspace hiện tại.

## Kiểm tra thủ công

1. Đăng nhập và tạo workspace mới.
2. Xác nhận workspace mới xuất hiện trong danh sách.
3. Đăng nhập bằng user khác và xác nhận workspace đó không xuất hiện.
4. Thử mở URL trực tiếp của workspace không tham gia và xác nhận nhận `404`.

Các vai trò Admin và Member được kiểm tra bằng test tự động và có thể cấu hình qua
màn hình quản lý thành viên.
