# Retrieval evaluation baseline

## Dataset và cấu hình

- Workspace thử nghiệm: `aa`.
- 15 câu hỏi: 12 answerable và 3 unanswerable.
- Embedding: `gemini-embedding-001`, 1.536 dimensions.
- Chunk size: 1.200 ký tự.
- Chunk overlap: 200 ký tự.
- Top K: 5.
- API error rate ở cả hai lần chạy: 0%.

## So sánh threshold

| Metric | Distance 0.65 | Distance 0.40 |
| --- | ---: | ---: |
| Hit Rate@5 | 100,0% (12/12) | 91,7% (11/12) |
| MRR@5 | 0,958 | 0,875 |
| No-answer accuracy | 0,0% (0/3) | 100,0% (3/3) |
| Overall accuracy | 80,0% (12/15) | 93,3% (14/15) |
| Total average latency | 523,1 ms | 531,7 ms |
| Total P95 latency | 935,6 ms | 1.007,9 ms |

## Quyết định

Chọn max cosine distance `0.40` làm baseline. Ngưỡng này loại được cả ba false
positive và tăng overall accuracy thêm 13,3 điểm phần trăm. Đánh đổi là một câu
answerable (`right-10`, distance khoảng 0,427) trở thành miss, nhưng Hit Rate@5
vẫn cao hơn mục tiêu 80%.

Total P95 ở lần chạy 0.40 vượt mục tiêu cũ 7,9 ms. Giá trị này bao gồm độ trễ gọi
Gemini query embedding nên không đại diện riêng cho PostgreSQL/pgvector. Hệ thống
đã được bổ sung stage timing và baseline cuối xác nhận mục tiêu dưới 1.000 ms áp
dụng cho pgvector P95 đã đạt.

## Baseline cuối với stage timing

| Metric | Kết quả |
| --- | ---: |
| Hit Rate@5 | 91,7% (11/12) |
| MRR@5 | 0,875 |
| No-answer accuracy | 100,0% (3/3) |
| Overall accuracy | 93,3% (14/15) |
| API error rate | 0,0% (0/15) |
| Total retrieval average / P95 | 491,4 / 748,2 ms |
| Query embedding average / P95 | 459,9 / 506,1 ms |
| PostgreSQL vector search average / P95 | 26,6 / 200,5 ms |

Kết quả từng case:

| Case | Kết quả | Rank | Total latency |
| --- | --- | ---: | ---: |
| right-1 | HIT | 1 | 748,2 ms |
| right-2 | HIT | 1 | 520,5 ms |
| right-3 | HIT | 1 | 449,5 ms |
| right-4 | HIT | 1 | 491,9 ms |
| right-5 | HIT | 1 | 445,4 ms |
| right-6 | HIT | 1 | 475,8 ms |
| right-7 | HIT | 1 | 470,9 ms |
| right-8 | HIT | 1 | 471,9 ms |
| right-9 | HIT | 2 | 482,0 ms |
| right-10 | MISS | - | 468,4 ms |
| right-11 | HIT | 1 | 479,2 ms |
| right-12 | HIT | 1 | 450,9 ms |
| unrelated-01 | NO_ANSWER CORRECT | - | 465,9 ms |
| unrelated-02 | NO_ANSWER CORRECT | - | 502,7 ms |
| unrelated-03 | NO_ANSWER CORRECT | - | 447,2 ms |

Tổng latency chủ yếu đến từ Gemini query embedding: trung bình 459,9 ms trên
tổng 491,4 ms. PostgreSQL vector search trung bình 26,6 ms, vì vậy pgvector không
phải nút thắt chính trên dataset demo này.

## Giới hạn của baseline

- Dataset chỉ có 15 câu hỏi và bốn PDF trong một workspace demo.
- Ground truth được gắn nhãn thủ công theo tiêu đề và số trang nên vẫn có khả
  năng sai sót chủ quan.
- Latency Gemini phụ thuộc mạng, quota và tải của provider tại thời điểm chạy.
- Evaluation này đo retrieval và no-answer detection, chưa đánh giá groundedness
  hoặc độ chính xác ngôn ngữ của câu trả lời do generation model tạo ra.
- Kết quả chưa đại diện cho workspace có hàng nghìn tài liệu; cần benchmark lại
  khi quy mô dữ liệu tăng đáng kể.

## Citation behavior

Retrieved chunks là candidate context, chưa tự động là citation. Codexys chỉ lưu
và hiển thị các chunk được Gemini tham chiếu bằng marker `[n]`. Khi retrieval trả
về rỗng, generation lỗi hoặc câu trả lời không có marker, giao diện không hiển thị
nguồn tham khảo.
