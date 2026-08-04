module DocumentsHelper
  STATUS_LABELS = {
    "pending" => "Chờ xử lý",
    "processing" => "Đang xử lý",
    "completed" => "Hoàn thành",
    "failed" => "Thất bại"
  }.freeze

  PROCESSING_ERROR_MESSAGES = {
    "page_limit_exceeded_error" =>
      "PDF vượt quá giới hạn #{Documents::ExtractText::MAX_PAGE_COUNT} trang.",
    "chunk_limit_exceeded_error" =>
      "Tài liệu tạo ra quá nhiều đoạn để xử lý an toàn."
  }.freeze

  def document_status_label(document)
    STATUS_LABELS.fetch(document.status, document.status)
  end

  def document_file_size(document)
    number_to_human_size(document.file.byte_size)
  end

  def document_processing_error_message(document)
    PROCESSING_ERROR_MESSAGES.fetch(
      document.error_code,
      "Hệ thống chưa thể xử lý tài liệu này."
    )
  end

  def document_lifecycle_time(timestamp)
    timestamp&.strftime("%d/%m/%Y %H:%M:%S") || "Chưa có"
  end
end
