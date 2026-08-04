# Phase 6 - Phát hiện tài liệu trùng bằng SHA-256

## Mục tiêu

Không xử lý và gọi embedding API nhiều lần cho cùng một nội dung PDF trong một
workspace.

## Quy tắc

- SHA-256 được tính từ bytes của file, không dựa vào tên file hoặc title.
- Cùng nội dung trong cùng workspace bị từ chối, kể cả khi đổi tên file.
- Cùng nội dung ở workspace khác vẫn được phép tải lên.
- `documents.content_sha256` lưu chuỗi SHA-256 dạng hexadecimal 64 ký tự.
- Dung lượng file không lặp lại trong `documents`; Active Storage đã lưu tại
  `active_storage_blobs.byte_size`.

## Luồng upload

1. Kiểm tra title, metadata, MIME type và PDF signature.
2. Đọc tempfile theo buffer 1 MB để tính SHA-256, không nạp toàn bộ PDF vào RAM.
3. Kiểm tra checksum trong phạm vi workspace trước khi tạo blob.
4. Gán checksum, attach file và lưu document.
5. Unique index `(workspace_id, content_sha256)` chặn hai request đồng thời.
6. Nếu request thua race condition, blob chưa gắn được purge và giao diện trả lỗi
   trùng tài liệu.

Các document cũ được tạo trước phase này có thể có checksum `NULL`. Upload mới
luôn có checksum; nullable được giữ lại để tương thích dữ liệu cũ và test fixture.

## Kiểm thử thủ công

1. Upload một PDF mới và chờ request thành công.
2. Đổi tên chính file đó rồi upload lại vào cùng workspace.
3. Kỳ vọng HTTP 422, không tạo document, blob hoặc processing job mới.
4. Upload file đó vào workspace khác.
5. Kỳ vọng upload thành công.

Có thể kiểm tra checksum và byte size bằng Rails console:

```ruby
document = Document.order(:created_at).last
document.content_sha256
document.file.blob.byte_size
```
