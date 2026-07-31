module DocumentsHelper
  STATUS_LABELS = {
    "pending" => "Chờ xử lý",
    "processing" => "Đang xử lý",
    "completed" => "Hoàn thành",
    "failed" => "Thất bại"
  }.freeze

  def document_status_label(document)
    STATUS_LABELS.fetch(document.status, document.status)
  end

  def document_file_size(document)
    number_to_human_size(document.file.byte_size)
  end
end
