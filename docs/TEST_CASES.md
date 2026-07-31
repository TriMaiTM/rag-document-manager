# BẢNG ĐẶC TẢ TEST CASE DỰ ÁN (TEST CASE SPECIFICATION)

Tài liệu này tổng hợp toàn bộ **96 Test Cases** của hệ thống theo dạng **Bảng Test Case Chuẩn** trong kiểm thử phần mềm (Software Testing Standard Table).

---

## 📊 Tổng Quan Danh Mục Kiểm Thử

| STT | Danh Mục Kiểm Thử | Số Lượng Test Suites | Số Lượng Test Cases | Kết Quả Kiểm Thử |
| :-: | :--- | :-: | :-: | :-: |
| 1 | **Models (Dữ liệu & Validations)** | 5 suites | 26 test cases | 100% PASS |
| 2 | **Services (Nghiệp vụ Xử lý)** | 5 suites | 21 test cases | 100% PASS |
| 3 | **Policies (Phân quyền Pundit)** | 3 suites | 14 test cases | 100% PASS |
| 4 | **Controllers (HTTP Endpoints)** | 7 suites | 35 test cases | 100% PASS |
| **Tổng** | **Toàn bộ hệ thống** | **20 suites** | **96 test cases** | **100% PASS** |

---

## 1. BẢNG TEST CASE CHO MODELS (DATA & VALIDATIONS)

### 1.1 Model User (`UserTest`)
📍 **File nguồn**: [user_test.rb](file:///mnt/d/HK9/TTTN/test/models/user_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 1 | TC-USR-01 | Chuẩn hóa email | Email có chữ hoa và khoảng trắng dư (vd: ` USER@ExAmPlE.CoM `) | Email được lưu tự động thành chữ thường và đã loại bỏ khoảng trắng (`user@example.com`). |
| 2 | TC-USR-02 | Kiểm tra User hợp lệ | Cung cấp đầy đủ email đúng định dạng và password | Record User hợp lệ (`valid? == true`), không có lỗi validation. |
| 3 | TC-USR-03 | Kiểm tra định dạng email | Email trống hoặc sai định dạng (vd: `invalid_email`) | Record không hợp lệ, trả về lỗi validation cho trường `email_address`. |
| 4 | TC-USR-04 | Kiểm tra email duy nhất | Đăng ký email đã tồn tại trong DB (không phân biệt hoa/thường) | Không cho phép lưu, báo lỗi email đã được sử dụng. |
| 5 | TC-USR-05 | Kiểm tra độ dài mật khẩu | Mật khẩu ít hơn 8 ký tự (vd: `1234567`) | Record không hợp lệ, yêu cầu mật khẩu phải từ 8 ký tự trở lên. |
| 6 | TC-USR-06 | Xác nhận mật khẩu | Mật khẩu mới và mật khẩu xác nhận không trùng khớp | Record không hợp lệ, yêu cầu password confirmation phải khớp. |

### 1.2 Model Workspace (`WorkspaceTest`)
📍 **File nguồn**: [workspace_test.rb](file:///mnt/d/HK9/TTTN/test/models/workspace_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 7 | TC-WKS-01 | Tạo Workspace hợp lệ | Nhập tên Workspace hợp lệ (vd: `Workspace A`) | Workspace hợp lệ, lưu thành công vào cơ sở dữ liệu. |
| 8 | TC-WKS-02 | Yêu cầu nhập tên Workspace | Tên Workspace bị để trống (`nil` hoặc `""`) | Không hợp lệ, trả về lỗi `name can't be blank`. |
| 9 | TC-WKS-03 | Giới hạn độ dài tên Workspace | Tên Workspace dài quá 100 ký tự | Không hợp lệ, trả về lỗi vượt quá 100 ký tự cho phép. |
| 10 | TC-WKS-04 | Mô tả Workspace tùy chọn | Mô tả (description) bị để trống | Record vẫn hợp lệ (`valid? == true`). |

### 1.3 Model Membership (`MembershipTest`)
📍 **File nguồn**: [membership_test.rb](file:///mnt/d/HK9/TTTN/test/models/membership_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 11 | TC-MBR-01 | Chấp nhận vai trò hợp lệ | Gán role là `owner`, `admin` hoặc `member` | Membership hợp lệ (`valid? == true`). |
| 12 | TC-MBR-02 | Từ chối vai trò không hợp lệ | Gán role không thuộc enum (vd: `superadmin`) | Báo lỗi ArgumentError / Invalid role. |
| 13 | TC-MBR-03 | Kiểm tra tính duy nhất | Thêm một User vào cùng 1 Workspace lần thứ 2 | Không cho phép, báo lỗi User đã thuộc Workspace. |
| 14 | TC-MBR-04 | Độc quyền vị trí Owner | Thêm Owner thứ 2 cho cùng 1 Workspace | Báo lỗi Workspace chỉ được có duy nhất 1 Owner. |
| 15 | TC-MBR-05 | Ràng buộc không đổi vai trò Owner | Thay đổi role của Owner sang `admin` hoặc `member` | Không hợp lệ, chặn việc thay đổi role của Owner. |
| 16 | TC-MBR-06 | Bảo vệ không xóa Owner | Thực hiện xóa trực tiếp Membership của Owner | Không cho phép xóa trực tiếp membership của Owner. |
| 17 | TC-MBR-07 | Xóa Cascade theo Workspace | Xóa thành công Workspace cha | Tự động xóa Membership của Owner liên quan (Cascade destroy). |

### 1.4 Model Document (`DocumentTest`)
📍 **File nguồn**: [document_test.rb](file:///mnt/d/HK9/TTTN/test/models/document_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 18 | TC-DOC-01 | Tạo Document với PDF hợp lệ | Nhập title và đính kèm file `sample.pdf` | Document hợp lệ (`valid? == true`). |
| 19 | TC-DOC-02 | Yêu cầu nhập tiêu đề | Title bị để trống | Báo lỗi `title can't be blank`. |
| 20 | TC-DOC-03 | Yêu cầu đính kèm file | Không đính kèm file tài liệu | Báo lỗi `file can't be blank`. |
| 21 | TC-DOC-04 | Kiểm tra Content-Type của file | Đính kèm file có Content-Type khác `application/pdf` | Báo lỗi chỉ chấp nhận file dạng PDF. |
| 22 | TC-DOC-05 | Kiểm tra đuôi mở rộng file | Đính kèm file không có đuôi `.pdf` (vd: `.docx`) | Báo lỗi file extension không hợp lệ. |
| 23 | TC-DOC-06 | Giới hạn dung lượng file | Đính kèm file PDF dung lượng > 20MB | Báo lỗi file quá dung lượng cho phép. |
| 24 | TC-DOC-07 | Kiểm tra enum Status | Gán status thuộc danh sách enum (`pending`, `completed`, `failed`) | Chỉ chấp nhận các trạng thái đã khai báo. |

### 1.5 Model DocumentChunk (`DocumentChunkTest`)
📍 **File nguồn**: [document_chunk_test.rb](file:///mnt/d/HK9/TTTN/test/models/document_chunk_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 25 | TC-CHK-01 | Khởi tạo Chunk hợp lệ | Nhập content, page_number (1), position (1) chưa có embedding | Chunk hợp lệ (`valid? == true`). |
| 26 | TC-CHK-02 | Yêu cầu nội dung Chunk | Trường `content` bị để trống | Báo lỗi `content can't be blank`. |
| 27 | TC-CHK-03 | Yêu cầu số trang dương | `page_number <= 0` (vd: 0 hoặc -1) | Báo lỗi `page_number must be greater than 0`. |
| 28 | TC-CHK-04 | Yêu cầu vị trí dương | `position <= 0` (vd: 0 hoặc -1) | Báo lỗi `position must be greater than 0`. |
| 29 | TC-CHK-05 | Duy nhất vị trí trong cùng version | Thêm 2 chunk trùng `position` trong cùng `processing_version` | Báo lỗi `position has already been taken`. |
| 30 | TC-CHK-06 | Cho phép trùng vị trí ở version mới | Thêm chunk trùng `position` nhưng `processing_version` khác (vd: v2) | Record hợp lệ (`valid? == true`). |
| 31 | TC-CHK-07 | Lưu Embedding đi kèm Metadata đầy đủ | Gán mảng `embedding` (1536 dims) và khai báo đủ provider/model/dimensions | Chunk hợp lệ (`valid? == true`). |
| 32 | TC-CHK-08 | Từ chối Embedding thiếu Metadata | Gán `embedding` nhưng bỏ trống provider/model/dimensions | Báo lỗi yêu cầu khai báo đủ metadata. |
| 33 | TC-CHK-09 | Từ chối Metadata thiếu Embedding | Khai báo metadata nhưng mảng `embedding` là `nil` | Báo lỗi `embedding phải có giá trị khi đã khai báo metadata`. |

---

## 2. BẢNG TEST CASE CHO SERVICES (LOGIC NGHIỆP VỤ)

### 2.1 Service Upload Tài Liệu (`Documents::UploadTest`)
📍 **File nguồn**: [upload_test.rb](file:///mnt/d/HK9/TTTN/test/services/documents/upload_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 34 | TC-SVC-UPL-01 | Upload file PDF thật | Truyền file PDF thực tế hợp lệ | Tạo Document, đính kèm ActiveStorage blob và trích xuất text thành công. |
| 35 | TC-SVC-UPL-02 | Từ chối file PDF giả | Truyền file text đổi tên đuôi thành `.pdf` | Upload thất bại, trả về lỗi định dạng tệp giả mạo. |
| 36 | TC-SVC-UPL-03 | Báo lỗi khi thiếu file | Không truyền file khi gọi service | Service trả về lỗi `file required`. |
| 37 | TC-SVC-UPL-04 | Không lưu Blob khi Metadata sai | File hoặc params kèm theo không hợp lệ | Không tạo ActiveStorage Blob dư thừa trong DB/Storage. |

### 2.2 Service Trích Xuất Văn Bản (`Documents::ExtractTextTest`)
📍 **File nguồn**: [extract_text_test.rb](file:///mnt/d/HK9/TTTN/test/services/documents/extract_text_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 38 | TC-SVC-EXT-01 | Trích xuất text & giữ số trang | File PDF 3 trang chứa văn bản | Trả về mảng 3 đối tượng `Page`, số trang từ 1 đến 3 chứa đúng text. |
| 39 | TC-SVC-EXT-02 | Giữ lại trang trắng | File PDF có trang không chứa chữ | Trang trắng vẫn được trả về với `text == ""`. |
| 40 | TC-SVC-EXT-03 | Từ chối PDF không có chữ | File PDF quét ảnh (scanned PDF/no text) | Trả về lỗi không thể trích xuất text. |
| 41 | TC-SVC-EXT-04 | Từ chối PDF bị lỗi cấu trúc | File PDF bị hỏng dữ liệu (corrupted) | Báo lỗi định dạng PDF không hợp lệ / không đọc được. |
| 42 | TC-SVC-EXT-05 | Yêu cầu file đính kèm | Gọi service với Document chưa đính kèm file | Báo lỗi yêu cầu file đính kèm. |

### 2.3 Service Tách Đoạn Văn Bản (`Documents::ChunkTextTest`)
📍 **File nguồn**: [chunk_text_test.rb](file:///mnt/d/HK9/TTTN/test/services/documents/chunk_text_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 43 | TC-SVC-CHK-01 | Chia chunk theo thứ tự trang | Danh sách các trang văn bản | Trả về danh sách `Chunk` sắp xếp theo thứ tự `position`, không ghép tràn trang. |
| 44 | TC-SVC-CHK-02 | Tách đoạn văn tại ranh giới câu | Đoạn văn dài vượt quá `max_chars` | Tách đoạn tại dấu kết thúc câu (`.!?`), độ dài mỗi chunk <= `max_chars`. |
| 45 | TC-SVC-CHK-03 | Tách câu dài không làm rách từ | Câu văn dài không chứa dấu câu | Tách theo từ (khoảng trắng), không cắt ngang giữa chừng của một từ. |
| 46 | TC-SVC-CHK-04 | Gối đầu (Overlap) từ chunk trước | `max_chars: 36`, `overlap_chars: 10` | Chunk thứ 2 chứa đoạn gối đầu từ cuối chunk thứ 1. |
| 47 | TC-SVC-CHK-05 | Cắt thô từ quá dài | Một từ liền duy nhất dài hơn `max_chars` | Cắt thô từ đó thành các đoạn nhỏ có độ dài bằng `max_chars`. |
| 48 | TC-SVC-CHK-06 | Từ chối max_chars không hợp lệ | `max_chars: 0` | Quăng ngoại lệ `ArgumentError`. |
| 49 | TC-SVC-CHK-07 | Từ chối overlap bằng max_chars | `max_chars: 20`, `overlap_chars: 20` | Quăng ngoại lệ `ArgumentError`. |

### 2.4 Service Tạo Workspace (`Workspaces::CreateTest`)
📍 **File nguồn**: [create_test.rb](file:///mnt/d/HK9/TTTN/test/services/workspaces/create_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 50 | TC-SVC-WKS-01 | Tạo Workspace & Owner đồng thời | Truyền thông tin User và tên Workspace | Tạo thành công Workspace và Membership vai trò `owner` cho User đó. |
| 51 | TC-SVC-WKS-02 | Rollback khi Workspace sai | Tên Workspace không hợp lệ (để trống) | Không tạo Workspace và không tạo bất kỳ Membership nào. |

### 2.5 Service Thêm Thành Viên (`Memberships::AddTest`)
📍 **File nguồn**: [add_test.rb](file:///mnt/d/HK9/TTTN/test/services/memberships/add_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Tiền Điều Kiện & Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 52 | TC-SVC-MBR-01 | Thêm thành viên theo Email | Nhập Email của User đã đăng ký | Tạo thành công Membership mới cho User trong Workspace. |
| 53 | TC-SVC-MBR-02 | Báo lỗi Email không tồn tại | Nhập Email chưa đăng ký tài khoản | Trả về lỗi không tìm thấy User với Email này. |
| 54 | TC-SVC-MBR-03 | Không thêm trùng thành viên | Nhập Email của User đã ở trong Workspace | Trả về lỗi User đã là thành viên của Workspace. |

---

## 3. BẢNG TEST CASE CHO POLICIES (PHÂN QUYỀN PUNDIT)

### 3.1 Policy Workspace (`WorkspacePolicyTest`)
📍 **File nguồn**: [workspace_policy_test.rb](file:///mnt/d/HK9/TTTN/test/policies/workspace_policy_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Vai Trò Thực Hiện | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 55 | TC-POL-WKS-01 | Quyền của Owner | `owner` | Được phép `show`, `update`, `destroy`. |
| 56 | TC-POL-WKS-02 | Quyền của Admin | `admin` | Được phép `show`, `update`, KHÔNG được `destroy`. |
| 57 | TC-POL-WKS-03 | Quyền của Member | `member` | Chỉ được phép `show`, KHÔNG được `update`, `destroy`. |
| 58 | TC-POL-WKS-04 | Quyền của Người ngoài | `outsider` | Bị từ chối toàn bộ quyền đối với Workspace. |
| 59 | TC-POL-WKS-05 | Scope truy vấn Workspace | User đăng nhập | Chỉ lấy danh sách các Workspace mà User đó có tham gia. |

### 3.2 Policy Membership (`MembershipPolicyTest`)
📍 **File nguồn**: [membership_policy_test.rb](file:///mnt/d/HK9/TTTN/test/policies/membership_policy_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Vai Trò Thực Hiện | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 60 | TC-POL-MBR-01 | Quản lý thành viên thông thường | `owner` / `admin` | Cho phép thêm/sửa/xóa các thành viên `member` hoặc `admin`. |
| 61 | TC-POL-MBR-02 | Member quản lý thành viên | `member` | Bị từ chối toàn bộ thao tác quản lý thành viên. |
| 62 | TC-POL-MBR-03 | Bảo vệ tài khoản Owner | `admin` / `owner` | Không được sửa hoặc xóa Membership của `owner`. |
| 63 | TC-POL-MBR-04 | Giới hạn phân quyền role | `admin` / `owner` | Chỉ được phép gán role `admin` hoặc `member`. |

### 3.3 Policy Document (`DocumentPolicyTest`)
📍 **File nguồn**: [document_policy_test.rb](file:///mnt/d/HK9/TTTN/test/policies/document_policy_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Vai Trò Thực Hiện | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 64 | TC-POL-DOC-01 | Quyền Owner với Tài liệu | `owner` | Được phép `show`, `create`, `download`, `destroy`. |
| 65 | TC-POL-DOC-02 | Quyền Admin với Tài liệu | `admin` | Được phép `show`, `create`, `download`, `destroy`. |
| 66 | TC-POL-DOC-03 | Quyền Member với Tài liệu | `member` | Được `show`, `download`; KHÔNG được `create`, `destroy`. |
| 67 | TC-POL-DOC-04 | Quyền Người ngoài với Tài liệu | `outsider` | Bị từ chối toàn bộ quyền đọc/tải/xóa tài liệu. |
| 68 | TC-POL-DOC-05 | Scope truy vấn Document | User đăng nhập | Chỉ trả về các tài liệu thuộc các Workspace mà User tham gia. |

---

## 4. BẢNG TEST CASE CHO CONTROLLERS (HTTP ENDPOINTS)

### 4.1 `HomeControllerTest`
📍 **File nguồn**: [home_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/home_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 69 | TC-CTL-HOM-01 | Trang chủ công khai | `GET /` | Trả về HTTP 200 OK, hiển thị giao diện trang chủ không cần đăng nhập. |

### 4.2 `SessionsControllerTest`
📍 **File nguồn**: [sessions_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/sessions_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 70 | TC-CTL-SES-01 | Form đăng nhập | `GET /session/new` | HTTP 200 OK, hiển thị form nhập Email/Password. |
| 71 | TC-CTL-SES-02 | Đăng nhập hợp lệ | `POST /session` (Đúng Email/Pass) | HTTP 302 Redirect, khởi tạo session thành công. |
| 72 | TC-CTL-SES-03 | Đăng nhập sai thông tin | `POST /session` (Sai Pass) | HTTP 422 Unprocessable Entity, báo lỗi đăng nhập. |
| 73 | TC-CTL-SES-04 | Đăng xuất | `DELETE /session` | HTTP 302 Redirect, hủy session thành công. |

### 4.3 `RegistrationsControllerTest`
📍 **File nguồn**: [registrations_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/registrations_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 74 | TC-CTL-REG-01 | Form đăng ký | `GET /registration/new` | HTTP 200 OK, mở form đăng ký tài khoản. |
| 75 | TC-CTL-REG-02 | Đăng ký tài khoản thành công | `POST /registration` (Params chuẩn) | Tạo User mới, tạo Session và Redirect về trang chủ. |
| 76 | TC-CTL-REG-03 | Đăng ký dữ liệu không hợp lệ | `POST /registration` (Pass ngắn) | HTTP 422 Unprocessable Entity, hiển thị lỗi validation. |
| 77 | TC-CTL-REG-04 | Đăng ký trùng Email | `POST /registration` (Email đã có) | HTTP 422 Unprocessable Entity, báo Email đã tồn tại. |
| 78 | TC-CTL-REG-05 | Đã đăng nhập truy cập đăng ký | `GET /registration/new` (Đã login) | HTTP 302 Redirect chuyển hướng người dùng đã đăng nhập. |

### 4.4 `PasswordsControllerTest`
📍 **File nguồn**: [passwords_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/passwords_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 79 | TC-CTL-PWD-01 | Form quên mật khẩu | `GET /passwords/new` | HTTP 200 OK. |
| 80 | TC-CTL-PWD-02 | Yêu cầu reset password | `POST /passwords` (Email đúng) | Gửi mail hướng dẫn và Redirect thông báo. |
| 81 | TC-CTL-PWD-03 | Quên pass email không có | `POST /passwords` (Email lạ) | Redirect thông báo an toàn, KHÔNG gửi mail (tránh lộ thông tin). |
| 82 | TC-CTL-PWD-04 | Form đổi pass hợp lệ | `GET /passwords/:token/edit` | HTTP 200 OK khi token còn hiệu lực. |
| 83 | TC-CTL-PWD-05 | Form đổi pass token sai | `GET /passwords/invalid/edit` | Redirect về trang quên pass, báo token hết hạn/sai. |
| 84 | TC-CTL-PWD-06 | Đổi mật khẩu thành công | `PUT /passwords/:token` (Pass khớp) | Cập nhật mật khẩu mới thành công, Redirect trang chủ. |
| 85 | TC-CTL-PWD-07 | Đổi pass không trùng khớp | `PUT /passwords/:token` (Xác nhận sai)| HTTP 422 Unprocessable Entity. |
| 86 | TC-CTL-PWD-08 | Đổi pass quá ngắn | `PUT /passwords/:token` (Pass < 8 ký tự)| HTTP 422 Unprocessable Entity. |

### 4.5 `WorkspacesControllerTest`
📍 **File nguồn**: [workspaces_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/workspaces_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 87 | TC-CTL-WKS-01 | Bắt buộc đăng nhập | `GET /workspaces` (Chưa login) | Redirect về trang đăng nhập. |
| 88 | TC-CTL-WKS-02 | Danh sách Workspace | `GET /workspaces` (Đã login) | HTTP 200 OK, trả về danh sách các workspace của user. |
| 89 | TC-CTL-WKS-03 | Xem chi tiết Workspace | `GET /workspaces/:id` | HTTP 200 OK. |
| 90 | TC-CTL-WKS-04 | Form tạo Workspace | `GET /workspaces/new` | HTTP 200 OK. |
| 91 | TC-CTL-WKS-05 | Tạo Workspace chuẩn | `POST /workspaces` (Tên đúng) | HTTP 302 Redirect đến Workspace vừa tạo. |
| 92 | TC-CTL-WKS-06 | Tạo Workspace lỗi | `POST /workspaces` (Tên trống) | HTTP 422 Unprocessable Entity. |
| 93 | TC-CTL-WKS-07 | Form sửa Workspace | `GET /workspaces/:id/edit` | HTTP 200 OK cho Owner / Admin. |
| 94 | TC-CTL-WKS-08 | Sửa Workspace chuẩn | `PATCH /workspaces/:id` | Cập nhật thành công, Redirect chi tiết. |
| 95 | TC-CTL-WKS-09 | Sửa Workspace lỗi | `PATCH /workspaces/:id` (Tên trống) | HTTP 422 Unprocessable Entity. |
| 96 | TC-CTL-WKS-10 | Xóa Workspace | `DELETE /workspaces/:id` | HTTP 302 Redirect danh sách, xóa workspace thành công. |
| 97 | TC-CTL-WKS-11 | Truy cập Workspace lạ | `GET /workspaces/other_id` | HTTP 404 Not Found. |
| 98 | TC-CTL-WKS-12 | Quyền Member với Wks | Member gọi `PATCH/DELETE` | Bị từ chối quyền (Redirect/Alert). |
| 99 | TC-CTL-WKS-13 | Quyền Admin xóa Wks | Admin gọi `DELETE` | Bị từ chối quyền xóa. |

### 4.6 `MembershipsControllerTest`
📍 **File nguồn**: [memberships_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/memberships_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 100 | TC-CTL-MBR-01 | Bắt buộc đăng nhập | `GET /workspaces/:wks_id/memberships` | Redirect trang đăng nhập. |
| 101 | TC-CTL-MBR-02 | Owner xem danh sách | `GET .../memberships` (Owner) | HTTP 200 OK. |
| 102 | TC-CTL-MBR-03 | Admin xem danh sách | `GET .../memberships` (Admin) | HTTP 200 OK. |
| 103 | TC-CTL-MBR-04 | Member xem danh sách | `GET .../memberships` (Member) | Bị từ chối quyền. |
| 104 | TC-CTL-MBR-05 | Người ngoài xem danh sách | `GET .../memberships` (Outsider) | HTTP 404 Not Found. |
| 105 | TC-CTL-MBR-06 | Owner thêm thành viên | `POST .../memberships` (Email chuẩn) | Thêm thành viên mới thành công. |
| 106 | TC-CTL-MBR-07 | Thêm Email chưa có | `POST .../memberships` (Email lạ) | HTTP 422 Unprocessable Entity. |
| 107 | TC-CTL-MBR-08 | Thêm trùng thành viên | `POST .../memberships` (Đã thuộc Wks) | HTTP 422 Unprocessable Entity. |
| 108 | TC-CTL-MBR-09 | Chặn tự phong Owner | `POST .../memberships` (Role: owner) | Không gán được role Owner. |
| 109 | TC-CTL-MBR-10 | Owner đổi role thành viên | `PATCH .../memberships/:id` | Cập nhật role thành công. |
| 110 | TC-CTL-MBR-11 | Admin đổi role thành viên | `PATCH .../memberships/:id` | Cập nhật role thành công. |
| 111 | TC-CTL-MBR-12 | Member đổi role người khác | `PATCH .../memberships/:id` (Member) | Bị từ chối quyền. |
| 112 | TC-CTL-MBR-13 | Đổi role của Owner | `PATCH .../memberships/:owner_id` | Bị chặn, giữ nguyên role Owner. |
| 113 | TC-CTL-MBR-14 | Admin xóa Owner | `DELETE .../memberships/:owner_id` | Admin bị từ chối xóa Owner. |
| 114 | TC-CTL-MBR-15 | Owner xóa thành viên | `DELETE .../memberships/:id` | Xóa thành viên khỏi Workspace thành công. |
| 115 | TC-CTL-MBR-16 | Thao tác nhầm Workspace | Request chéo Workspace ID khác | HTTP 404 Not Found. |

### 4.7 `DocumentsControllerTest`
📍 **File nguồn**: [documents_controller_test.rb](file:///mnt/d/HK9/TTTN/test/controllers/documents_controller_test.rb)

| STT | Mã TC | Tên / Mô Tả Test Case | Endpoint / Request | Kết Quả Kỳ Vọng (Expected Result) |
| :-: | :--- | :--- | :--- | :--- |
| 116 | TC-CTL-DOC-01 | Bắt buộc đăng nhập | `GET /workspaces/:wks_id/documents` | Redirect về trang login. |
| 117 | TC-CTL-DOC-02 | Xem danh sách tài liệu | `GET .../documents` (Owner) | HTTP 200 OK. |
| 118 | TC-CTL-DOC-03 | Xem chi tiết tài liệu | `GET .../documents/:id` | HTTP 200 OK. |
| 119 | TC-CTL-DOC-04 | Upload tài liệu PDF thật | `POST .../documents` (File PDF) | HTTP 302 Redirect, lưu file và đọc text thành công. |
| 120 | TC-CTL-DOC-05 | Upload tài liệu PDF giả | `POST .../documents` (File giả) | HTTP 422 Unprocessable Entity. |
| 121 | TC-CTL-DOC-06 | Upload không chọn file | `POST .../documents` (Thiếu file) | HTTP 422 Unprocessable Entity. |
| 122 | TC-CTL-DOC-07 | Tải xuống tài liệu | `GET .../documents/:id/download` | HTTP 200 OK, trả về luồng dữ liệu file (send_data). |
| 123 | TC-CTL-DOC-08 | Xóa tài liệu | `DELETE .../documents/:id` (Owner) | Xóa tài liệu thành công, Redirect danh sách. |
| 124 | TC-CTL-DOC-09 | Phân quyền Member | Member xem/tải vs xóa | Member đọc/tải OK, nhưng xóa bị từ chối. |
| 125 | TC-CTL-DOC-10 | Người ngoài xem tài liệu | Outsider gửi request | HTTP 404 Not Found. |
| 126 | TC-CTL-DOC-11 | Xem tài liệu chéo Wks | Truy cập Doc ID thuộc Wks khác | HTTP 404 Not Found. |
