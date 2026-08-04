class Document < ApplicationRecord
  MAX_FILE_SIZE = 20.megabytes
  PDF_CONTENT_TYPE = "application/pdf"

  belongs_to :workspace
  belongs_to :uploaded_by,
    class_name: "User",
    inverse_of: :uploaded_documents

  has_many :document_chunks, dependent: :destroy, inverse_of: :document
  has_many :chat_message_sources, dependent: :nullify

  has_one_attached :file

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, validate: true

  validates :title,
    presence: true,
    length: { maximum: 200 }

  validates :processing_version,
    numericality: {
      only_integer: true,
      greater_than: 0
    }

  validates :page_count,
    numericality: {
      only_integer: true,
      greater_than: 0
    },
    allow_nil: true

  validate :file_must_be_attached
  validate :file_must_be_pdf
  validate :file_size_must_be_allowed

  private

  def file_must_be_attached
    return if file.attached?

    errors.add(:file, "phải được chọn")
  end

  def file_must_be_pdf
    return unless file.attached?

    unless file.blob.content_type == PDF_CONTENT_TYPE
      errors.add(:file, "phải có content type application/pdf")
    end

    unless file.filename.extension_without_delimiter.downcase == "pdf"
      errors.add(:file, "phải có phần mở rộng .pdf")
    end
  end

  def file_size_must_be_allowed
    return unless file.attached?
    return if file.blob.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "không được lớn hơn 20 MB")
  end
end
