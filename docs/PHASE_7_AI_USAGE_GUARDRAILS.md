# Phase 7 - Giới hạn tài nguyên và chi phí AI

## Mục tiêu

Ngăn một tài liệu quá lớn tiêu tốn hết quota embedding hoặc làm background job
sử dụng quá nhiều bộ nhớ.

## Giới hạn

- Dung lượng file: tối đa 20 MB.
- Số trang PDF: tối đa 100 trang.
- Số chunk: tối đa 500 chunk cho mỗi processing version.
- Kích thước embedding batch: 64 chunk/request.

Với 500 chunk, pipeline tạo tối đa khoảng 8 embedding batch request cho một
lần xử lý tài liệu.

## Thứ tự kiểm tra

1. Upload request kiểm tra metadata, MIME type, chữ ký PDF và dung lượng.
2. Background job mở PDF và đọc `page_count`.
3. Nếu vượt 100 trang, job dừng trước khi trích xuất toàn bộ nội dung và trước
   khi khởi tạo embedding generator.
4. Sau khi chunking, nếu vượt 500 chunk, pipeline dừng trước embedding.
5. Document chuyển sang `failed` với `error_code` an toàn.

## Dữ liệu page_count

`documents.page_count` nullable vì file vừa upload chưa được background job đọc.
Khi PDF được mở thành công, số trang được lưu kể cả khi bước sau thất bại.
Database có check constraint bảo đảm giá trị chỉ có thể là `NULL` hoặc số dương.

## Thông báo lỗi

Giao diện chỉ hiển thị thông báo đã ánh xạ theo `error_code`, ví dụ PDF vượt
giới hạn trang. `error_message` kỹ thuật không được render để tránh lộ chi tiết
nhà cung cấp hoặc parser.
