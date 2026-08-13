# Codexys UI Design System

Tài liệu này mô tả hệ thống giao diện hiện tại của Codexys. Thiết kế lấy cảm hứng từ cách AnythingLLM tổ chức workspace và chat, nhưng giữ màu sắc, logo, nội dung và nghiệp vụ riêng của Codexys.

## 1. Nguyên tắc

- Dùng layout co giãn theo viewport, không đặt element theo tọa độ cố định từ Figma.
- Mỗi màn hình chỉ có một vùng cuộn chính; sidebar và composer giữ vị trí ổn định.
- Dùng cùng một bộ token cho màu, khoảng cách, border, radius và shadow.
- Mọi nút phải là element thật trong document flow. Không dùng một ảnh lớn rồi đặt vùng click tuyệt đối lên ảnh.
- Desktop ưu tiên panel; mobile chuyển sidebar và Sources thành drawer.

## 2. Typography

- Font chính: `Plus Jakarta Sans`.
- Body: 14px, line-height 1.55.
- Heading lớn: 25–34px.
- Heading card: 15–20px.
- Label và metadata: 9–12px.
- Trọng lượng thường dùng: 400, 500, 600 và 700.

## 3. Color tokens

| Token | Value | Mục đích |
| --- | --- | --- |
| `--ui-bg` | `#f8fafc` | Nền ngoài ứng dụng |
| `--ui-surface` | `#ffffff` | Panel, card, input |
| `--ui-sidebar` | `#edf2fa` | Nền sidebar |
| `--ui-text` | `#111827` | Heading và nội dung quan trọng |
| `--ui-muted` | `#6f6f71` | Metadata, mô tả |
| `--ui-border` | `#d8dee8` | Border mặc định |
| `--ui-primary` | `#1681ef` | CTA và trạng thái active |
| `--ui-primary-soft` | `#e5f0ff` | Hover và selected nhẹ |
| `--ui-success` | `#138a5b` | Hoàn thành, owner |
| `--ui-danger` | `#b42318` | Xóa và lỗi |

## 4. Layout

### Desktop

- App shell chiếm `100dvh`.
- Sidebar rộng 292px.
- Panel sidebar cách mép 16px và bo 16px.
- Main stage có margin `16px 16px 16px 2px`, bo 16px.
- Nội dung chat rộng tối đa 900px.
- Sources drawer rộng 360px khi mở.

### Mobile

- Breakpoint chính: 900px.
- Header mobile cao 56px.
- Sidebar là drawer phủ bên trái và có backdrop.
- Sources là drawer phủ toàn chiều rộng.
- Composer luôn nằm cuối vùng chat và không tạo horizontal overflow.

## 5. Components

### Sidebar

- Nút tạo Workspace nằm trên cùng.
- Tìm kiếm lọc Workspace và cuộc trò chuyện.
- Mỗi Workspace có drag handle, tên, nút quản lý tài liệu và nút cài đặt.
- Kéo drag handle để đổi thứ tự; thứ tự được lưu riêng trên membership của từng user.
- Workspace active dùng nền xanh nhạt và mở danh sách cuộc trò chuyện bên dưới.
- Danh sách cuộc trò chuyện chỉ mở dưới Workspace active.
- Profile được ghim cuối sidebar.

### Chat

- Empty state đặt nội dung và composer trong container tối đa 750px.
- Hội thoại dùng container tối đa 900px.
- Câu trả lời hiển thị Sources button bên dưới.
- Sources đóng mặc định và chỉ mở sau khi user bấm nút.
- Composer tự tăng chiều cao, Enter để gửi và Shift+Enter để xuống dòng.

### Management pages

- Documents, Members và Settings là trang/panel bình thường trong app stage.
- Không dùng backdrop blur giả modal cho các route riêng.
- Form và table phải co giãn; table thành viên được phép cuộn ngang trên màn hình nhỏ.
- Cài đặt tài khoản thay nội dung app stage, không mở dưới dạng modal.
- Mục cài đặt có navigation riêng để bổ sung nhóm Giao diện, Thông báo và Quyền riêng tư sau này.

### Icons và focus

- Toàn bộ action icon dùng Ionicons 7, tránh trộn nhiều phong cách SVG khác nhau.
- Logo Codexys là ngoại lệ và tiếp tục dùng asset thương hiệu riêng.
- Input focus dùng border xám đậm hơn kèm shadow trung tính nhẹ, không dùng vòng xanh nổi bật.
- Button và link vẫn giữ focus-visible trung tính để hỗ trợ điều hướng bằng bàn phím.

### Buttons

- Primary: hành động chính duy nhất của vùng hiện tại.
- Secondary: điều hướng hoặc thao tác phụ.
- Ghost: hủy, menu nhẹ.
- Danger: xóa dữ liệu.

## 6. Quy tắc khi dựng lại trong Figma

- Dùng Auto Layout cho sidebar, card, table row, toolbar và composer.
- Dùng Fill container cho vùng chat; chỉ đặt max-width cho nội dung bên trong.
- Không khóa chiều cao nội dung động như message, document row hoặc error panel.
- Tạo variables từ các token trong `app/assets/stylesheets/application.css`.
- Kiểm tra tối thiểu ba frame: 1440px desktop, 1024px laptop và 390px mobile.

## 7. Nguồn tham khảo

- AnythingLLM source: <https://github.com/Mintplex-Labs/anything-llm>
- AnythingLLM Chat UI: <https://docs.useanything.com/chat-ui>
- AnythingLLM product: <https://www.anythingllm.co/>
- Ionicons: <https://ionic.io/ionicons>
