# Codexys ERD

ERD này phản ánh schema Rails/PostgreSQL sau khi chuyển authentication sang
Devise và dùng PostgreSQL native enum cho vai trò cùng trạng thái tài liệu.

```mermaid
erDiagram
    users {
        bigint id PK
        string email UK "null: false"
        string encrypted_password "null: false"
        string reset_password_token UK "nullable"
        datetime reset_password_sent_at "nullable"
        datetime remember_created_at "nullable"
        enum system_role "user_system_role; null: false; default: user"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    workspaces {
        bigint id PK
        string name "null: false"
        text description "nullable"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    memberships {
        bigint id PK
        bigint user_id FK "null: false"
        bigint workspace_id FK "null: false"
        enum role "membership_role; null: false"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    documents {
        bigint id PK
        bigint workspace_id FK "null: false"
        bigint uploaded_by_id FK "null: false"
        string title "null: false"
        enum status "document_status; null: false; default: pending"
        string content_sha256 "nullable; limit: 64"
        integer processing_version "null: false; default: 1"
        integer page_count "nullable; positive when present"
        string error_code "nullable"
        text error_message "nullable"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    document_chunks {
        bigint id PK
        bigint document_id FK "null: false"
        text content "null: false"
        integer page_number "null: false"
        integer position "null: false"
        integer processing_version "null: false; default: 1"
        vector embedding "nullable; limit: 1536"
        string embedding_provider "nullable"
        string embedding_model "nullable"
        integer embedding_dimensions "nullable"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    chat_sessions {
        bigint id PK
        bigint workspace_id FK "null: false"
        bigint user_id FK "null: false"
        string title "null: false"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    chat_messages {
        bigint id PK
        bigint chat_session_id FK "null: false"
        enum role "chat_message_role; null: false"
        enum status "chat_message_status; null: false; default: completed"
        text content "null: false"
        string error_code "nullable; limit: 100"
        string model "nullable"
        integer prompt_tokens "null: false; default: 0"
        integer candidate_tokens "null: false; default: 0"
        integer total_tokens "null: false; default: 0"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    chat_message_sources {
        bigint id PK
        bigint chat_message_id FK "null: false"
        bigint document_id FK "nullable"
        bigint document_chunk_id FK "nullable"
        integer rank "null: false"
        string document_title "null: false"
        integer page_number "null: false"
        text content "null: false"
        float cosine_distance "null: false"
        datetime created_at "null: false"
        datetime updated_at "null: false"
    }

    active_storage_blobs {
        bigint id PK
        string key UK "null: false"
        string filename "null: false"
        string content_type "nullable"
        text metadata "nullable"
        string service_name "null: false"
        bigint byte_size "null: false"
        string checksum "nullable"
        datetime created_at "null: false"
    }

    active_storage_attachments {
        bigint id PK
        string name "null: false"
        string record_type "null: false"
        bigint record_id "null: false"
        bigint blob_id FK "null: false"
        datetime created_at "null: false"
    }

    active_storage_variant_records {
        bigint id PK
        bigint blob_id FK "null: false"
        string variation_digest "null: false"
    }

    users ||--o{ memberships : has
    workspaces ||--|{ memberships : has
    users ||--o{ documents : uploads
    workspaces ||--o{ documents : contains
    documents ||--o{ document_chunks : splits
    users ||--o{ chat_sessions : owns
    workspaces ||--o{ chat_sessions : contains
    chat_sessions ||--o{ chat_messages : has
    chat_messages ||--o{ chat_message_sources : cites
    documents o|--o{ chat_message_sources : snapshots
    document_chunks o|--o{ chat_message_sources : snapshots
    documents ||--o| active_storage_attachments : "file (polymorphic)"
    active_storage_blobs ||--o{ active_storage_attachments : attaches
    active_storage_blobs ||--o{ active_storage_variant_records : variants
```

## Enum types

- `membership_role`: `owner`, `admin`, `member`.
- `user_system_role`: `user`, `system_admin`.
- `document_status`: `pending`, `processing`, `completed`, `failed`.
- `chat_message_role`: `user`, `assistant`.
- `chat_message_status`: `completed`, `failed`.

`memberships.role` vẫn là quyền theo từng workspace và độc lập với Devise.
Devise chỉ chịu trách nhiệm authentication. Bảng `sessions` tự viết đã được
loại bỏ; phiên đăng nhập mặc định được Devise/Warden quản lý bằng cookie.

`documents.page_count` nullable trong lúc file mới chờ xử lý. Sau khi đọc được
cấu trúc PDF, hệ thống lưu số trang dương; check constraint PostgreSQL không
cho phép lưu `0` hoặc số âm.
