class AddProcessingTimestampsToDocuments < ActiveRecord::Migration[8.1]
  def up
    add_column :documents, :processing_started_at, :datetime
    add_column :documents, :completed_at, :datetime
    add_column :documents, :failed_at, :datetime

    execute <<~SQL.squish
      UPDATE documents
      SET processing_started_at = updated_at
      WHERE status IN ('processing', 'completed', 'failed')
    SQL

    execute <<~SQL.squish
      UPDATE documents
      SET completed_at = updated_at
      WHERE status = 'completed'
    SQL

    execute <<~SQL.squish
      UPDATE documents
      SET failed_at = updated_at
      WHERE status = 'failed'
    SQL

    add_check_constraint :documents,
      lifecycle_timestamps_constraint,
      name: "documents_lifecycle_timestamps_match_status"
  end

  def down
    remove_check_constraint :documents,
      name: "documents_lifecycle_timestamps_match_status"

    remove_column :documents, :failed_at
    remove_column :documents, :completed_at
    remove_column :documents, :processing_started_at
  end

  private

  def lifecycle_timestamps_constraint
    <<~SQL.squish
      (
        status = 'pending'
        AND processing_started_at IS NULL
        AND completed_at IS NULL
        AND failed_at IS NULL
      ) OR (
        status = 'processing'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failed_at IS NULL
      ) OR (
        status = 'completed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NOT NULL
        AND failed_at IS NULL
        AND completed_at >= processing_started_at
      ) OR (
        status = 'failed'
        AND processing_started_at IS NOT NULL
        AND completed_at IS NULL
        AND failed_at IS NOT NULL
        AND failed_at >= processing_started_at
      )
    SQL
  end
end
