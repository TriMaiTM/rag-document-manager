# Convention dự án Knowledge Hub

Tài liệu này là luật làm việc chung. Mục đích là giúp code dễ đọc, dễ kiểm
thử và tránh các lỗi nguy hiểm của ứng dụng đa workspace.

## 1. Ngôn ngữ

- Tên class, method, biến, database và commit viết bằng tiếng Anh.
- Nội dung giao diện và thông báo cho người dùng có thể viết tiếng Việt.
- Tài liệu giải thích có thể viết tiếng Việt.
- Không dùng tên viết tắt nếu người đọc phải đoán ý nghĩa.

Ví dụ tốt:

```ruby
current_workspace
document_chunk
similarity_score
```

Ví dụ cần tránh:

```ruby
cw
doc_chk
sim
```

## 2. Trách nhiệm của từng lớp

### Model

Model giữ:

- Quan hệ dữ liệu.
- Validation.
- Trạng thái và quy tắc bất biến.
- Các scope truy vấn ngắn, dùng lại nhiều lần.

Model không trực tiếp gọi AI, đọc PDF hoặc gửi HTTP request.

### Controller

Controller chỉ:

1. Nhận request.
2. Xác định current user/workspace.
3. Kiểm tra quyền.
4. Gọi model hoặc service.
5. Trả response.

Không viết thuật toán chunking, gọi AI hoặc xử lý PDF trong controller.

### Service

Đặt luồng nghiệp vụ trong `app/services`.

Tên theo phạm vi và hành động:

```text
app/services/documents/extract_text.rb
app/services/documents/chunk_text.rb
app/services/documents/process.rb
app/services/embeddings/create.rb
app/services/rag/retrieve.rb
app/services/rag/answer.rb
```

Mỗi service có một nhiệm vụ chính và một public method dễ đoán, thường là
`call`.

### Job

Job chỉ điều phối công việc chạy nền:

```ruby
class ProcessDocumentJob < ApplicationJob
  queue_as :documents

  def perform(document_id)
    document = Document.find(document_id)
    Documents::Process.new(document: document).call
  end
end
```

Job nhận ID, không nhận nội dung PDF, embedding hoặc hash dữ liệu lớn.

### Policy

Mọi hành động phụ thuộc quyền phải đi qua policy. Không rải điều kiện role ở
nhiều controller.

```ruby
if membership.admin?
  # Không làm kiểu này ở nhiều nơi.
end
```

Thay vào đó:

```ruby
authorize document, :destroy?
```

## 3. Quy tắc tuyệt đối cho multi-tenancy

Không tìm record thuộc workspace bằng model gốc:

```ruby
# Sai
Document.find(params[:id])
Conversation.find(params[:id])
```

Luôn đi từ workspace hiện tại:

```ruby
# Đúng
Current.workspace.documents.find(params[:id])
Current.workspace.conversations.find(params[:id])
```

Vector search cũng phải lọc workspace trong câu SQL trước khi `ORDER BY`
distance và `LIMIT`.

Không được:

1. Tìm top K chunk trên toàn hệ thống.
2. Sau đó mới xóa các chunk không thuộc workspace.

Mọi lỗi truy cập chéo workspace phải có request test.

## 4. Vai trò

- `system_admin`: quyền vận hành toàn hệ thống.
- `owner`: sở hữu một workspace.
- `admin`: quản lý thành viên và tài liệu trong workspace.
- `member`: đọc tài liệu và đặt câu hỏi.

System role thuộc `User`. Workspace role thuộc `Membership`. Không trộn hai
loại role vào cùng một cột.

Mỗi workspace phải luôn có đúng một Owner. Chọn `Membership` làm nguồn sự
thật cho ownership; không lưu thêm `workspaces.owner_id` trừ khi có lý do và
cơ chế đồng bộ được kiểm thử.

## 5. Trạng thái

Dùng giá trị string dễ đọc trong database:

```ruby
enum :status, {
  pending: "pending",
  processing: "processing",
  completed: "completed",
  failed: "failed"
}, validate: true
```

Không cập nhật trạng thái tùy ý ở nhiều nơi. Việc chuyển trạng thái nằm trong
service xử lý tài liệu.

## 6. Database

Mỗi bảng cần cân nhắc:

- Foreign key.
- `null: false`.
- Unique index.
- Index cho trường thường lọc hoặc sắp xếp.
- Hành vi khi record cha bị xóa.

Ví dụ Membership phải có unique index:

```ruby
add_index :memberships, [:workspace_id, :user_id], unique: true
```

Không chỉnh migration cũ sau khi migration đã được dùng chung. Tạo migration
mới để thay đổi schema.

Embedding cần lưu kèm:

- Tên provider.
- Tên model.
- Số chiều.
- Phiên bản pipeline.

Không đổi embedding model trong cùng một vector column mà không có kế hoạch
re-embed.

## 7. Xử lý tài liệu

PDF đầu vào được xem là dữ liệu không đáng tin cậy.

- Kiểm tra extension và content type thực.
- Giới hạn dung lượng và số trang.
- Chỉ hỗ trợ PDF có text ở phiên bản đầu.
- Không ghi toàn bộ nội dung tài liệu vào log.
- Tính `content_sha256` để phát hiện cùng nội dung.
- Giữ `page_number` từ lúc extraction đến citation.

Chunk ưu tiên theo đoạn và token. Không cắt mù theo đúng 1.000 ký tự nếu việc
đó làm mất ranh giới câu hoặc trang.

## 8. Job phải chạy lại an toàn

Một job có thể chạy nhiều lần. Kết quả cuối không được có chunk trùng.

Quy trình khuyến nghị:

1. Khóa document cần xử lý.
2. Kiểm tra `processing_version`.
3. Chuyển trạng thái sang `processing`.
4. Tạo kết quả mới trong transaction phù hợp.
5. Chỉ chuyển `completed` sau khi tất cả bước thành công.
6. Khi lỗi, lưu loại lỗi và chuyển `failed`.

Đặt timeout và retry có giới hạn cho API ngoài. Không retry vô hạn lỗi do file
không hợp lệ.

## 9. AI và RAG

Không gọi SDK của nhà cung cấp trực tiếp từ controller, model hoặc job.

```text
Controller -> Rag::Answer -> Ai::Client
Job        -> Embeddings::Create -> Ai::Client
```

`Ai::Client` là lớp bọc duy nhất biết cấu trúc API của nhà cung cấp.

Prompt phải:

- Nói rõ tài liệu là dữ liệu tham khảo, không phải chỉ dẫn hệ thống.
- Yêu cầu chỉ trả lời từ context.
- Cho phép từ chối khi context không đủ.
- Yêu cầu citation theo ID chunk được cấp.
- Không đưa API key, thông tin nội bộ hoặc dữ liệu workspace khác vào prompt.

Lưu metadata cần thiết để tái hiện kết quả:

- Model.
- Prompt version.
- Retrieval configuration.
- Token usage.
- Chunk IDs.

## 10. Citation

Citation phải bền vững. Ngoài foreign key tới chunk, lưu snapshot tối thiểu:

- `document_title`.
- `page_number`.
- `excerpt`.
- `similarity_score`.
- `position`.

Nhờ vậy lịch sử trả lời vẫn giải thích được khi document được xử lý lại. Nếu
cho phép xóa vĩnh viễn tài liệu, phải quy định rõ citation cũ sẽ hiển thị thế
nào.

## 11. Error và logging

Tạo lỗi theo domain:

```ruby
Documents::UnsupportedPdfError
Documents::EmptyTextError
Ai::RateLimitError
Rag::InsufficientContextError
```

Log nên có:

- `user_id`.
- `workspace_id`.
- `document_id`.
- `job_id`.
- Thời gian xử lý.
- Tên bước bị lỗi.

Log không được có:

- API key.
- Password hoặc reset token.
- Toàn bộ prompt.
- Toàn bộ nội dung tài liệu.

## 12. Testing

Tên test mô tả hành vi:

```ruby
test "member cannot delete a workspace"
test "retrieval never returns chunks from another workspace"
test "retry does not create duplicate chunks"
```

Mức kiểm thử:

- Model test cho validation và invariant.
- Request test cho authentication và authorization.
- Service test cho extraction, chunking và retrieval.
- Job test cho enqueue, retry và trạng thái.
- System test cho kịch bản demo chính.

Mỗi bug sau khi sửa phải có một regression test.

Không gọi API AI thật trong test tự động. Dùng fake client hoặc response
fixture.

## 13. Git

Tên branch:

```text
feature/workspace-membership
feature/document-upload
fix/cross-workspace-access
test/document-processing-retry
```

Commit:

```text
feat: add workspace membership
fix: scope vector search by workspace
test: cover document retry idempotency
docs: explain RAG evaluation
refactor: extract embedding client
chore: update development dependencies
```

Một commit nên có một mục đích. Không trộn format toàn project với một thay
đổi nghiệp vụ nhỏ.

## 14. Style Ruby

- Thụt đầu dòng hai khoảng trắng.
- Ưu tiên guard clause để giảm lồng `if`.
- Method nên có một nhiệm vụ và tên thể hiện hành động.
- Không dùng callback cho một luồng nghiệp vụ dài.
- Không viết comment để lặp lại điều code đã nói rõ.
- Comment giải thích lý do hoặc đánh đổi, không giải thích cú pháp.
- Chạy formatter/linter trước khi commit.

Ví dụ:

```ruby
def call
  return Result.failure(:empty_question) if question.blank?

  chunks = retrieve_chunks
  return Result.failure(:insufficient_context) if chunks.empty?

  generate_answer(chunks)
end
```

## 15. Definition of Done

Một chức năng chỉ được xem là xong khi:

- Luồng thành công chạy được.
- Luồng lỗi quan trọng có xử lý.
- Authorization đã kiểm tra.
- Test liên quan đang xanh.
- Không có dữ liệu nhạy cảm trong log.
- Migration có foreign key/index phù hợp.
- Giao diện có thông báo dễ hiểu.
- Tài liệu hoặc README đã cập nhật nếu cách sử dụng thay đổi.

