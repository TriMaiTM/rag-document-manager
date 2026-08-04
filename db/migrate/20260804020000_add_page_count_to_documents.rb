class AddPageCountToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :page_count, :integer

    add_check_constraint :documents,
      "page_count IS NULL OR page_count > 0",
      name: "documents_page_count_positive"
  end
end
