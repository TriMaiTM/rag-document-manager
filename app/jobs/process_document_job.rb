class ProcessDocumentJob < ApplicationJob
  queue_as :documents

  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound

  retry_on Ai::GeminiClient::NetworkError,
    Ai::GeminiClient::RetryableRequestError,
    wait: :polynomially_longer,
    attempts: 3

  def perform(document_id)
    document = Document.find(document_id)

    Documents::ProcessDocument.new(document: document).call
  end
end
