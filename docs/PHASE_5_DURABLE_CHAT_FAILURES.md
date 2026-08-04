# Phase 5 - Lưu bền vững câu hỏi khi AI gặp lỗi

## Vấn đề

Nếu chỉ lưu lịch sử sau khi Gemini trả lời thành công, timeout hoặc lỗi mạng sẽ
làm mất câu hỏi của người dùng. Người dùng không thể biết câu nào đã thất bại
và hệ thống cũng không có dữ liệu để theo dõi lỗi.

## Luồng mới

1. Kiểm tra và chuẩn hóa câu hỏi trước khi ghi database.
2. Tạo `chat_session` nếu cần và lưu user message.
3. Gọi semantic retrieval và Gemini generation.
4. Nếu thành công, lưu assistant message `completed` cùng citation snapshot.
5. Nếu AI lỗi, lưu assistant message `failed` cùng `error_code` an toàn.
6. Nếu retrieval đã tìm được chunk trước khi generation lỗi, các nguồn đó vẫn
   được snapshot để người dùng có thể kiểm tra nội dung liên quan.

## Dữ liệu lỗi

`chat_messages.status` là PostgreSQL enum:

- `completed`: tin nhắn bình thường.
- `failed`: Gemini không thể tạo câu trả lời.

`error_code` chỉ lưu mã ngắn như `network_error`. Response body, API key và
thông báo kỹ thuật từ nhà cung cấp không được lưu vào nội dung chat hoặc hiển
thị trên giao diện.

User message luôn có trạng thái `completed`. Chỉ assistant message mới có thể
ở trạng thái `failed`; quy tắc này được bảo vệ bằng cả validation Rails và
check constraint PostgreSQL.

## Hội thoại nhiều lượt

Assistant message thất bại không được đưa trở lại prompt của lượt tiếp theo.
Câu hỏi của người dùng vẫn được giữ trong lịch sử để người dùng nhìn thấy chính
xác thao tác đã thực hiện.
