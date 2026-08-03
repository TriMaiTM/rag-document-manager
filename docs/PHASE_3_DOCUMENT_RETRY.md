# Phase 3 - Retry xử lý tài liệu

## Mục tiêu

Cho phép Owner hoặc Admin chạy lại pipeline đối với tài liệu có trạng thái
`failed` mà không làm hỏng chunk và citation của các lần xử lý trước.

## Luồng xử lý

1. Người dùng mở trang chi tiết của tài liệu `failed`.
2. Hệ thống kiểm tra quyền `retry_processing?` bằng Pundit.
3. `Documents::RetryProcessing` khóa record tài liệu.
4. Service tăng `processing_version`, chuyển trạng thái về `pending` và xóa
   thông tin lỗi cũ.
5. Controller enqueue `ProcessDocumentJob`.
6. Job extract, chunk và tạo embedding cho version mới.
7. Tài liệu chuyển thành `completed` hoặc trở lại `failed` nếu có lỗi.

## Vì sao phải tăng processing_version?

Mỗi lần retry là một phiên bản xử lý độc lập. Chunk của phiên bản cũ được giữ
lại để citation đã lưu vẫn đọc được. Semantic search chỉ truy vấn chunk có
`processing_version` bằng version hiện tại của tài liệu, nên dữ liệu cũ không
bị đưa vào kết quả tìm kiếm mới.

Unique index `(document_id, processing_version, position)` ngăn một phiên bản
tạo hai chunk cùng vị trí.

## Quyền truy cập

- Owner: được retry.
- Admin của workspace: được retry.
- Member: không được retry.
- Người ngoài workspace: không thể tìm thấy tài liệu.

## Kiểm thử thủ công

1. Làm một tài liệu chuyển sang trạng thái `failed`.
2. Mở trang chi tiết và bấm **Thử xử lý lại**.
3. Kiểm tra trạng thái chuyển sang `pending`, sau đó `processing`.
4. Khi job hoàn thành, kiểm tra trạng thái là `completed`.
5. Đăng nhập Member và xác nhận không thấy nút retry.
