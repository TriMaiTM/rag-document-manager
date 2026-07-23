# Lộ trình dự án Knowledge Hub

## 1. Mục tiêu cuối cùng

Xây dựng một ứng dụng Ruby on Rails đa người dùng cho phép:

1. Quản lý tài khoản và workspace.
2. Tải lên tài liệu PDF có lớp văn bản.
3. Xử lý tài liệu bằng background job.
4. Lưu embedding trong PostgreSQL với pgvector.
5. Đặt câu hỏi và nhận câu trả lời dựa trên tài liệu.
6. Hiển thị chính xác tài liệu, số trang và đoạn văn được dùng làm nguồn.
7. Chứng minh dữ liệu giữa các workspace được cách ly.
8. Đo được chất lượng truy xuất và thời gian xử lý.

Nguyên tắc triển khai: mỗi giai đoạn phải tạo ra một phần chạy được, có kiểm
thử và có tiêu chí hoàn thành rõ ràng.

## 2. Stack đã chốt

- Ruby 3.4.x.
- Ruby on Rails 8.1.x.
- PostgreSQL 17 và pgvector.
- ERB, Turbo, Stimulus và CSS/Tailwind.
- Active Storage.
- Active Job với Solid Queue.
- Rails authentication generator.
- Pundit và policy object cho authorization.
- Minitest là bộ kiểm thử mặc định.
- Docker cho PostgreSQL và môi trường triển khai.

Không dùng microservice ở phiên bản đầu. Không thêm Redis, React hoặc một
framework frontend riêng khi chưa có yêu cầu thực tế.

## 3. Các giai đoạn

### Giai đoạn 0 - Môi trường và project skeleton

Mục tiêu:

- Cài WSL2, Ruby và Rails.
- Tạo project Rails dùng PostgreSQL.
- Chạy PostgreSQL có pgvector bằng Docker.
- Chạy được trang Rails ở môi trường development.
- Chạy được toàn bộ test mặc định.

Hoàn thành khi:

- `ruby --version`, `rails --version` và `docker --version` đều chạy được.
- `bin/rails db:prepare` thành công.
- `bin/rails runner "puts ActiveRecord::Base.connection.database_version"`
  thành công.
- `bin/rails test` xanh.
- Commit đầu tiên được tạo.

### Giai đoạn 1 - RAG technical spike

Mục tiêu:

- Chứng minh chuỗi kỹ thuật khó nhất trước khi xây nhiều giao diện.
- Đọc một PDF có text.
- Giữ được số trang khi trích xuất.
- Chia nội dung thành chunk.
- Tạo embedding và lưu vào pgvector.
- Tạo embedding cho câu hỏi và tìm top K chunk.
- Sinh câu trả lời có citation.

Phạm vi:

- Chạy bằng Rails console hoặc `rails runner`.
- Chưa cần đăng nhập, workspace hoặc giao diện chat hoàn chỉnh.
- Chỉ dùng một nhà cung cấp AI và một embedding model.

Hoàn thành khi:

- Có ít nhất ba PDF mẫu.
- Có ít nhất 15 câu hỏi có đáp án biết trước.
- Mỗi kết quả trả về tên file, số trang, đoạn trích và similarity score.
- Không gọi LLM nếu kết quả truy xuất thấp hơn ngưỡng cấu hình.
- Có test cho chunking và retrieval.

### Giai đoạn 2 - Authentication và workspace

Mục tiêu:

- Đăng ký, đăng nhập, đăng xuất và đặt lại mật khẩu.
- Tạo workspace.
- Thêm thành viên.
- Phân quyền Owner, Admin và Member.
- Thiết lập `Current.user` và `Current.workspace`.

Hoàn thành khi:

- Người ngoài workspace nhận `404` hoặc `403`.
- Member không thể sửa workspace hoặc quản lý thành viên.
- Admin không thể xóa Owner.
- Owner không thể tự làm workspace rơi vào trạng thái không có Owner.
- Request test bao phủ truy cập chéo workspace.

### Giai đoạn 3 - Quản lý tài liệu

Mục tiêu:

- Upload PDF bằng Active Storage.
- Kiểm tra dung lượng, content type và PDF có text.
- Hiển thị danh sách và trạng thái xử lý.
- Cho phép retry tài liệu lỗi.
- Xóa tài liệu theo quy tắc đã định.

Hoàn thành khi:

- Request upload chỉ lưu file, tạo record và enqueue job.
- Việc trích xuất không chạy trong request.
- Trạng thái đi đúng luồng:
  `pending -> processing -> completed` hoặc `failed`.
- Retry không tạo chunk trùng lặp.
- Không thể tải file thuộc workspace khác bằng URL trực tiếp.

### Giai đoạn 4 - Pipeline xử lý tài liệu

Mục tiêu:

- Chuyển spike thành code production.
- Tách các bước extract, normalize, chunk và embed.
- Có retry, idempotency, logging và xử lý lỗi.
- Giới hạn concurrency khi gọi embedding API.

Hoàn thành khi:

- Mỗi job chỉ nhận ID và tự tải record cần xử lý.
- Có `content_sha256` và `processing_version`.
- Reprocess cùng một phiên bản không tạo dữ liệu trùng.
- Lỗi lưu loại lỗi và thông báo dễ hiểu nhưng không lộ bí mật.
- Có job test và service test cho từng bước chính.

### Giai đoạn 5 - Conversation, RAG và citation

Mục tiêu:

- Tạo conversation và message.
- Vector search luôn được scope theo workspace trước khi lấy top K.
- Tạo prompt có ranh giới rõ giữa chỉ dẫn và nội dung tài liệu.
- Sinh câu trả lời hoặc từ chối khi thiếu dữ liệu.
- Lưu citation bền vững.

Hoàn thành khi:

- Mỗi câu trả lời chỉ dùng chunk thuộc workspace hiện tại.
- Citation còn đọc được nếu tài liệu bị ẩn hoặc được xử lý lại.
- Người dùng mở được tài liệu, trang và đoạn trích tương ứng.
- Lỗi hoặc timeout từ AI không làm mất câu hỏi đã lưu.
- Có test chống truy cập chéo workspace ở tầng retrieval.

### Giai đoạn 6 - Giao diện và trải nghiệm

Mục tiêu:

- Giao diện workspace, tài liệu và chat dễ sử dụng.
- Trạng thái xử lý được cập nhật bằng polling hoặc Turbo.
- Responsive ở mức sử dụng tốt trên desktop và điện thoại.
- Thông báo lỗi có hành động tiếp theo rõ ràng.

Hoàn thành khi:

- Kịch bản demo chính chạy liên tục từ đăng ký đến xem citation.
- Không có trang bắt buộc phải dùng Rails console.
- System test bao phủ kịch bản demo.

### Giai đoạn 7 - Đánh giá, bảo mật và vận hành

Mục tiêu:

- Đánh giá retrieval bằng bộ câu hỏi chuẩn.
- Đánh giá groundedness và citation correctness.
- Chạy kiểm tra bảo mật và chất lượng code.
- Theo dõi lỗi job và chi phí AI.

Chỉ số ban đầu:

- Hit Rate@5 trên bộ dữ liệu demo: tối thiểu 80%.
- 100% test truy cập chéo workspace phải xanh.
- Vector search trên dữ liệu demo: mục tiêu dưới 1 giây.
- Request upload enqueue job: mục tiêu dưới 2 giây, không tính thời gian
  truyền file từ máy người dùng.

Hoàn thành khi:

- `bin/rails test`, RuboCop và Brakeman đều chạy thành công.
- Có báo cáo kết quả retrieval.
- Có giới hạn file, số trang và số lần gọi AI.
- Log không chứa API key hoặc toàn bộ nội dung tài liệu.

### Giai đoạn 8 - Tính năng nâng cao

Chỉ bắt đầu sau khi giai đoạn 7 ổn định:

- Email invitation.
- Feedback chi tiết.
- Dashboard người dùng và quản trị viên.
- Audit log.
- Khóa/mở tài khoản.
- Streaming câu trả lời.
- Hybrid search.
- Re-ranking.
- OCR và thêm loại file.

Mỗi tính năng nâng cao phải có use case, quyền truy cập, migration, test và
tiêu chí demo riêng. Không thêm tính năng chỉ để tăng số lượng màn hình.

### Giai đoạn 9 - Triển khai và báo cáo

Mục tiêu:

- Đóng gói và triển khai ứng dụng.
- Tách web process và job process.
- Cấu hình PostgreSQL, pgvector, object storage và HTTPS.
- Viết tài liệu cài đặt, kiến trúc, kiểm thử và đánh giá.

Hoàn thành khi:

- Một máy mới có thể chạy project theo README.
- Có backup database và hướng khôi phục cơ bản.
- Demo production chạy được toàn bộ kịch bản chính.
- Báo cáo giải thích được các quyết định và đánh đổi kỹ thuật.

## 4. Thứ tự ưu tiên cố định

Khi phải chọn giữa hai việc, dùng thứ tự sau:

1. Không rò rỉ dữ liệu.
2. Citation đúng và có thể kiểm chứng.
3. Job chạy lại an toàn.
4. Test và khả năng quan sát lỗi.
5. Trải nghiệm người dùng.
6. Tối ưu hiệu năng.
7. Tính năng bổ sung.

## 5. Quy tắc chuyển giai đoạn

Không chuyển giai đoạn chỉ vì “đã viết gần xong code”. Chỉ chuyển khi:

- Tiêu chí hoàn thành đã đạt.
- Test liên quan đã có và đang xanh.
- Không còn lỗi nghiêm trọng đã biết.
- README hoặc tài liệu kỹ thuật đã phản ánh thay đổi.
- Có một commit rõ ràng để quay lại khi cần.
