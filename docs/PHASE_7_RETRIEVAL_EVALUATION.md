# Phase 7 - Đánh giá semantic retrieval

## Mục tiêu

Đo chất lượng tìm chunk trước khi đánh giá câu trả lời của LLM. Việc này tách
hai câu hỏi khác nhau:

1. Hệ thống có tìm đúng tài liệu/trang không?
2. Gemini có tổng hợp đúng từ các nguồn đã tìm không?

Phase này chỉ đo câu hỏi thứ nhất và không gọi generation model.

## Chuẩn bị ground-truth dataset

Sao chép file mẫu:

```bash
cp config/rag_evaluation.example.yml config/rag_evaluation.yml
```

Mỗi case gồm:

```yaml
- id: devise-password-01
  question: "Devise lưu mật khẩu như thế nào?"
  answerable: true
  expected_sources:
    - document_title: "Rails Authentication Guide"
      page_number: 3
```

`document_title` phải khớp tiêu đề document trong Workspace. Nếu đáp án có thể
nằm ở bất kỳ trang nào của tài liệu, đặt `page_number: null`. Một câu hỏi có thể
có nhiều expected sources.

`answerable` mặc định là `true` để tương thích với dataset cũ. Câu hỏi không có
đáp án trong bộ tài liệu phải được đánh dấu rõ:

```yaml
- id: unrelated-01
  question: "Tài liệu có hướng dẫn cách sửa xe máy không?"
  answerable: false
  expected_sources: []
```

Case không có đáp án chỉ được tính đúng khi retrieval không trả về chunk nào sau
khi áp dụng similarity threshold. Không được gắn expected source cho case này.

Dataset chính thức phải có ít nhất 15 câu hỏi dựa trên tối thiểu 3 PDF và nên gồm:

- câu hỏi factual trực tiếp;
- câu hỏi diễn đạt lại bằng từ khác;
- câu hỏi không có đáp án.

Case ID phải duy nhất và dataset phải có ít nhất một câu hỏi có đáp án.

## Chạy evaluation

Lần đầu chạy không có cờ xác nhận để xem trước chi phí:

```bash
bin/rails rag:evaluate \
  WORKSPACE_ID=1 \
  DATASET=config/rag_evaluation.yml
```

Task sẽ in số embedding request dự kiến rồi dừng. Khi đã kiểm tra dataset:

```bash
bin/rails rag:evaluate \
  WORKSPACE_ID=1 \
  DATASET=config/rag_evaluation.yml \
  K=5 \
  CONFIRM_AI_COST=1
```

Mỗi case tạo một query embedding request. Task không gọi Gemini generation.
Rate limit của web không áp dụng cho task chạy nội bộ có xác nhận rõ ràng.

Ngưỡng retrieval mặc định sau lần baseline đầu tiên là `0.40`. Có thể thử một
ngưỡng khác mà không sửa code:

```bash
SEMANTIC_SEARCH_MAX_COSINE_DISTANCE=0.35 \
WORKSPACE_ID=1 \
DATASET=config/rag_evaluation.yml \
K=5 \
CONFIRM_AI_COST=1 \
bin/rails rag:evaluate
```

Cosine distance càng nhỏ thì hai vector càng gần nghĩa. Hạ ngưỡng giảm false
positive nhưng có thể loại bỏ một số nguồn đúng, vì vậy phải so sánh cả Hit Rate,
MRR và No-answer accuracy.

## Metrics

- `Hit Rate@5`: tỷ lệ câu hỏi có ít nhất một expected source trong top 5.
- `MRR@5`: trung bình nghịch đảo thứ hạng nguồn đúng đầu tiên. Nguồn đúng ở rank 1
  được 1 điểm, rank 2 được 0,5 điểm và miss được 0 điểm.
- `No-answer accuracy`: tỷ lệ câu không có đáp án mà retrieval trả về rỗng.
- `Overall accuracy`: tỷ lệ case được xử lý đúng trên toàn bộ dataset.
- `API error rate`: tỷ lệ case lỗi provider/hệ thống. Error vẫn ảnh hưởng kết quả
  chung nhưng được báo riêng, không bị hiểu nhầm là lỗi chất lượng retrieval.
- `hit_rank`: vị trí đầu tiên của nguồn đúng trong kết quả.
- `total retrieval latency`: tổng thời gian query embedding, pgvector và phần xử
  lý Ruby.
- `query embedding latency`: thời gian gọi Gemini để embedding câu hỏi.
- `PostgreSQL vector search latency`: thời gian truy vấn và lọc chunk trong
  PostgreSQL/pgvector.
- `P95`: 95% case không vượt giá trị này ở từng giai đoạn.

Mục tiêu ban đầu:

- Hit Rate@5 tối thiểu 80%.
- PostgreSQL vector search P95 dưới 1.000 ms trên bộ dữ liệu demo.

Không dùng total retrieval P95 để kết luận pgvector chậm vì phần lớn giá trị đó có
thể đến từ mạng và Gemini embedding API.

Case bị lỗi API được ghi là incorrect kèm tên error class; evaluation tiếp tục với
các case còn lại và báo riêng `API error rate`.

## Báo cáo

Mặc định report được ghi tại:

```text
tmp/rag_evaluation_YYYYMMDDHHMMSS.json
```

Có thể chọn đường dẫn khác bằng `REPORT=...`. JSON report chỉ chứa câu hỏi,
tên tài liệu, trang, rank, cosine distance và latency. Nó không chứa toàn văn
chunk, API key hoặc response body của Gemini.

Report cũng lưu embedding provider/model/dimensions, chunk size, overlap, top K và
max cosine distance để một lần chạy có thể được tái tạo và so sánh công bằng.

## Citation trên giao diện

Retrieval result chỉ là các candidate chunk. Nó chỉ trở thành citation khi câu trả
lời Gemini thực sự tham chiếu marker `[1]`, `[2]` tương ứng. Codexys chỉ lưu và
hiển thị các chunk đã được tham chiếu; câu trả lời từ chối, câu trả lời không có
marker hoặc request generation thất bại sẽ không có citation.

Report JSON là bằng chứng có thể đưa vào phần thực nghiệm của đồ án và dùng để
so sánh trước/sau khi đổi chunk size, threshold hoặc embedding model.

Baseline đã chọn và lý do tuning được ghi tại
[`docs/RETRIEVAL_BASELINE.md`](RETRIEVAL_BASELINE.md).
