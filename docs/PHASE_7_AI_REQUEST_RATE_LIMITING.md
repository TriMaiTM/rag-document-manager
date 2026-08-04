# Phase 7 - Rate limit yêu cầu AI

## Mục tiêu

Ngăn một người dùng gửi liên tục semantic search hoặc câu hỏi RAG, gây cạn
Gemini free-tier quota và làm tăng tải cho ứng dụng.

## Giới hạn

- Burst limit: 5 yêu cầu trong 1 phút cho mỗi user.
- Sustained limit: 20 yêu cầu trong 1 giờ cho mỗi user.

Một yêu cầu hỏi đáp thường tạo một embedding request và một generation request.
Ngưỡng 5 câu/phút giữ tải dự kiến khoảng 10 Gemini request/phút, thấp hơn đáng
kể so với quota 100 RPM đã chọn cho môi trường demo.

## Phạm vi dùng chung

Ba luồng sau dùng chung một counter theo `Current.user.id`:

- Semantic search.
- Bắt đầu chat session.
- Gửi câu hỏi tiếp theo trong chat session.

Vì scope dùng chung nên người dùng không thể chuyển controller hoặc workspace
để né giới hạn. Mỗi tài khoản có counter riêng.

Trang semantic search chỉ bị tính khi request có tham số `query`; mở form tìm
kiếm mà chưa hỏi không làm mất lượt.

## Lưu counter

- Development dùng cache store của Rails.
- Test dùng `ActiveSupport::Cache::MemoryStore` riêng và được reset giữa test.
- Production dùng Solid Cache đã cấu hình trong Rails.

Không cần Redis và không thêm bảng nghiệp vụ mới.

## Khi vượt giới hạn

Ứng dụng trả HTTP `429 Too Many Requests`, kèm header:

```text
Retry-After: 60
```

hoặc `3600` nếu chạm giới hạn giờ. Request bị chặn trước `Chat::Ask` hoặc RAG,
vì vậy không gọi Gemini và không tạo chat message mới.

Rate limit này chỉ bảo vệ request tương tác của người dùng. Background job xử
lý tài liệu được bảo vệ riêng bằng giới hạn 100 trang, 500 chunk và batch size.
