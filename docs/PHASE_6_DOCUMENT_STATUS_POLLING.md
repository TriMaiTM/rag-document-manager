# Phase 6 - Tự động cập nhật trạng thái tài liệu

## Mục tiêu

Hiển thị tiến trình xử lý tài liệu trên trang danh sách và chi tiết mà người
dùng không phải tự tải lại trang.

## Cách hoạt động

1. View chỉ gắn Stimulus controller cho tài liệu có trạng thái `pending` hoặc
   `processing`.
2. Trình duyệt gọi endpoint `processing_status` mỗi 2 giây.
3. Endpoint đọc trạng thái hiện tại từ PostgreSQL và trả JSON.
4. Stimulus thay nhãn trạng thái trên trang.
5. Khi trạng thái là `completed` hoặc `failed`, trang tải lại một lần để hiển
   thị đầy đủ các hành động mới rồi dừng polling.

Request polling không gọi Gemini, không tạo embedding và không tiêu tốn quota
AI. Nó chỉ thực hiện một truy vấn đọc nhỏ tới database.

## JSON contract

```json
{
  "status": "processing",
  "label": "Đang xử lý",
  "terminal": false,
  "updated_at": "2026-08-04T10:00:00Z"
}
```

Response được đặt `no-cache` để trình duyệt không hiển thị trạng thái cũ.

## Bảo mật

- Endpoint đi qua Devise và Pundit.
- Document luôn được tìm bên trong workspace hiện tại.
- Thành viên workspace được xem trạng thái.
- Người ngoài workspace nhận `404`.
- Polling dừng khi nhận `401`, `403` hoặc `404`.
