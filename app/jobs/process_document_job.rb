class ProcessDocumentJob < ApplicationJob
  queue_as :documents

  limits_concurrency to: 1,
    key: ->(document_id, _processing_version) { document_id },
    duration: 30.minutes,
    group: "DocumentProcessing"

  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  retry_on Ai::GeminiClient::NetworkError,
    Ai::GeminiClient::RetryableRequestError,
    wait: :polynomially_longer,
    attempts: 3

  def perform(document_id, processing_version)
    document = Document.find(document_id)
    return unless current_processing_version?(document, processing_version)
    return if document.completed?

    Documents::ProcessDocument.new(document: document).call
  end

  private

  def current_processing_version?(document, expected_version)
    document.processing_version == expected_version
  end
end
