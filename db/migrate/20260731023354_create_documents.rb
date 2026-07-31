class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :workspace,
        null: false,
        foreign_key: true

      t.references :uploaded_by,
        null: false,
        foreign_key: { to_table: :users }

      t.string :title, null: false
      t.string :status, null: false, default: "pending"

      t.string :content_sha256, limit: 64
      t.integer :processing_version, null: false, default: 1

      t.string :error_code
      t.text :error_message

      t.timestamps
    end

    add_index :documents,
      [ :workspace_id, :created_at ]

    add_index :documents,
      [ :workspace_id, :content_sha256 ],
      unique: true,
      where: "content_sha256 IS NOT NULL",
      name: "index_documents_on_workspace_and_content_sha256"

    add_check_constraint :documents,
      "status IN ('pending', 'processing', 'completed', 'failed')",
      name: "documents_status_check"
  end
end
