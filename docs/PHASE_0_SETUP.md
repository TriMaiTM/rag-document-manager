# Giai đoạn 0 - Cài môi trường và tạo project

Các lệnh dưới đây được viết để chép và chạy theo thứ tự. Dùng PowerShell cho
bước cài WSL; sau đó dùng terminal Ubuntu cho toàn bộ lệnh Rails.

## 1. Cài WSL2

Mở PowerShell bằng quyền Administrator:

```powershell
wsl --install --distribution Ubuntu-24.04
```

Khởi động lại Windows nếu được yêu cầu. Mở ứng dụng Ubuntu và tạo username,
password Linux.

## 2. Cài công cụ trong Ubuntu

Chạy trong terminal Ubuntu:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  rustc \
  libssl-dev \
  libyaml-dev \
  zlib1g-dev \
  libgmp-dev \
  libpq-dev \
  git \
  curl
```

Cài Mise để quản lý phiên bản Ruby:

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

Cài Ruby và Rails:

```bash
mise use -g ruby@3.4
gem update --system
gem install rails --version 8.1.3
```

Kiểm tra:

```bash
ruby --version
rails --version
bundle --version
```

Kết quả mong đợi:

- Ruby thuộc nhánh 3.4.
- Rails là 8.1.3.
- Bundler chạy được.

## 3. Tạo project

Đi tới workspace dùng chung:

```bash
cd /mnt/d/HK9/TTTN
```

Tạo Rails app trong thư mục `knowledge_hub`:

```bash
rails new knowledge_hub \
  --database=postgresql \
  --css=tailwind
cd knowledge_hub
```

Rails mặc định đã tích hợp Hotwire gồm Turbo và Stimulus.

Chép roadmap và convention vào repository mới:

```bash
mkdir -p docs
cp ../docs/ROADMAP.md docs/
cp ../docs/CONVENTIONS.md docs/
cp ../docs/PHASE_0_SETUP.md docs/
```

## 4. Thêm PostgreSQL có pgvector

Tạo file `compose.yml` ở thư mục gốc của Rails app:

```yaml
services:
  db:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
```

Khởi động database:

```bash
docker compose up -d db
docker compose ps
```

## 5. Cấu hình kết nối development

Trong `config/database.yml`, bảo đảm phần `default` có các trường sau. Giữ
nguyên các phần `development`, `test` và `production` do Rails tạo:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>
  port: <%= ENV.fetch("DATABASE_PORT", 5432) %>
  username: <%= ENV.fetch("DATABASE_USERNAME", "postgres") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "postgres") %>
```

Giá trị mặc định `postgres/postgres` chỉ dùng cho database development chạy
cục bộ. Production bắt buộc dùng secret riêng.

## 6. Thêm các gem nền tảng

Thêm vào `Gemfile`:

```ruby
# Vector type cho PostgreSQL
gem "pgvector"

# Active Record API cho nearest-neighbor search
gem "neighbor"

# Đọc PDF có lớp văn bản
gem "pdf-reader"

# Authorization bằng policy object
gem "pundit"
```

Chưa chạy generator của Pundit và chưa thêm SDK AI ở giai đoạn 0. Pundit sẽ
được cấu hình ở giai đoạn authentication; SDK AI sẽ được thêm ở RAG spike sau
khi chốt nhà cung cấp và model.

Cài gem:

```bash
bundle install
```

## 7. Bật extension vector

Tạo migration:

```bash
bin/rails generate migration EnableVectorExtension
```

Mở migration vừa tạo và sửa thành:

```ruby
class EnableVectorExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"
  end
end
```

Chuẩn bị database:

```bash
bin/rails db:prepare
```

Kiểm tra extension:

```bash
bin/rails runner \
  'puts ActiveRecord::Base.connection.extension_enabled?("vector")'
```

Kết quả phải là:

```text
true
```

## 8. Chạy project và test

Chạy test:

```bash
bin/rails test
```

Chạy development server:

```bash
bin/dev
```

Mở:

```text
http://localhost:3000
```

## 9. Khởi tạo Git

Chỉ chạy trong thư mục `knowledge_hub`:

```bash
git init
git add .
git commit -m "chore: initialize Rails application"
```

## 10. Kiểm tra cuối giai đoạn

Chạy lần lượt:

```bash
ruby --version
rails --version
docker compose ps
bin/rails db:prepare
bin/rails runner \
  'puts ActiveRecord::Base.connection.extension_enabled?("vector")'
bin/rails test
```

Không chuyển sang giai đoạn 1 nếu một trong các lệnh trên còn lỗi.

## 11. Khi gặp lỗi

Gửi lại:

1. Lệnh đã chạy.
2. Toàn bộ thông báo lỗi đầu tiên.
3. Kết quả của `ruby --version`.
4. Kết quả của `rails --version`.
5. Kết quả của `docker compose ps`.

Không cài thêm gem ngẫu nhiên để “thử sửa” trước khi xác định nguyên nhân.
