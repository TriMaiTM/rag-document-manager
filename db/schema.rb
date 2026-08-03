# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_03_063400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "document_status", ["pending", "processing", "completed", "failed"]
  create_enum "membership_role", ["owner", "admin", "member"]

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "document_chunks", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.vector "embedding", limit: 1536
    t.integer "embedding_dimensions"
    t.string "embedding_model"
    t.string "embedding_provider"
    t.integer "page_number", null: false
    t.integer "position", null: false
    t.integer "processing_version", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "processing_version", "page_number"], name: "index_document_chunks_on_document_page"
    t.index ["document_id", "processing_version", "position"], name: "index_document_chunks_unique_position", unique: true
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
    t.index ["embedding"], name: "index_document_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.check_constraint "\"position\" > 0", name: "document_chunks_position_positive"
    t.check_constraint "char_length(btrim(content)) > 0", name: "document_chunks_content_not_blank"
    t.check_constraint "embedding IS NULL AND embedding_provider IS NULL AND embedding_model IS NULL AND embedding_dimensions IS NULL OR embedding IS NOT NULL AND embedding_provider::text = 'openai'::text AND embedding_model::text = 'text-embedding-3-small'::text AND embedding_dimensions = 1536", name: "document_chunks_embedding_metadata_consistent"
    t.check_constraint "page_number > 0", name: "document_chunks_page_number_positive"
    t.check_constraint "processing_version > 0", name: "document_chunks_processing_version_positive"
  end

  create_table "documents", force: :cascade do |t|
    t.string "content_sha256", limit: 64
    t.datetime "created_at", null: false
    t.string "error_code"
    t.text "error_message"
    t.integer "processing_version", default: 1, null: false
    t.enum "status", default: "pending", null: false, enum_type: "document_status"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
    t.index ["workspace_id", "content_sha256"], name: "index_documents_on_workspace_and_content_sha256", unique: true, where: "(content_sha256 IS NOT NULL)"
    t.index ["workspace_id", "created_at"], name: "index_documents_on_workspace_id_and_created_at"
    t.index ["workspace_id"], name: "index_documents_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.enum "role", null: false, enum_type: "membership_role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_unique_workspace_owner", unique: true, where: "(role = 'owner'::membership_role)"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "document_chunks", "documents", on_delete: :cascade
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "documents", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
end
