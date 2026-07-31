# Phase 2B - Quản lý thành viên Workspace

## Mục tiêu

Owner và Admin có một màn hình riêng để:

- Xem thành viên trong workspace.
- Thêm một tài khoản đã đăng ký bằng email.
- Gán vai trò `admin` hoặc `member`.
- Đổi vai trò giữa Admin và Member.
- Xóa Admin hoặc Member khỏi workspace.

Member không được mở màn hình này. Người ngoài workspace nhận `404` trước khi hệ
thống tìm membership.

## Vì sao chưa mời qua email?

Phase này chỉ thêm tài khoản đã tồn tại. Nếu email chưa đăng ký, form trả lỗi và
không tạo record tạm.

Email invitation cần token, thời hạn, mailer và quy tắc chấp nhận lời mời. Đây là
một nghiệp vụ riêng trong nhóm tính năng nâng cao, không trộn vào membership đang
hoạt động.

## Quy tắc Owner

Membership Owner bị khóa:

1. Không thể đổi thành Admin hoặc Member.
2. Không thể bị xóa bởi Owner, Admin hoặc request thủ công.
3. Vẫn được xóa theo cascade khi xóa toàn bộ workspace.
4. Request không thể tạo thêm Owner.

Policy bảo vệ request và model callback bảo vệ cả console hoặc code nội bộ.
Partial unique index tiếp tục bảo đảm một workspace không có hai Owner khi có race
condition.

Việc chuyển Owner chưa nằm trong phase này. Khi cần, nó phải là một service riêng
đổi Owner cũ và Owner mới trong cùng transaction.

## Luồng thêm thành viên

`Memberships::Add` thực hiện:

1. Chuẩn hóa email bằng cách bỏ khoảng trắng và chuyển về chữ thường.
2. Tìm `User` đã đăng ký.
3. Khởi tạo membership trong `Current.workspace`.
4. Lưu role đã được policy giới hạn ở `admin` hoặc `member`.

Unique index và model validation chặn việc thêm cùng một user hai lần.

## Ranh giới truy vấn

Controller luôn tìm workspace qua `policy_scope(Workspace)`, sau đó mới tìm:

```ruby
@workspace.memberships.find(params[:id])
```

Không dùng:

```ruby
Membership.find(params[:id])
```

Nhờ vậy ID membership của workspace khác không thể được dùng để cập nhật hoặc xóa
dữ liệu chéo workspace.

## Kiểm tra thủ công

1. Đăng ký ít nhất hai tài khoản.
2. Tài khoản thứ nhất tạo workspace và mở `Quản lý thành viên`.
3. Thêm tài khoản thứ hai với role Member.
4. Đăng nhập tài khoản thứ hai và xác nhận xem được workspace nhưng không thấy
   liên kết quản lý thành viên.
5. Tài khoản thứ nhất đổi tài khoản thứ hai thành Admin.
6. Đăng nhập tài khoản thứ hai và xác nhận mở được màn hình thành viên, nhưng
   không thể sửa hoặc xóa Owner.
7. Xóa tài khoản thứ hai khỏi workspace và xác nhận workspace biến mất khỏi danh
   sách của tài khoản đó.
