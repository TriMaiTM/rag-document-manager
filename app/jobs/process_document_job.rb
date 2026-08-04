class ProcessDocumentJob < ApplicationJob
  queue_as :documents

  discard_on ActiveJob::DeserializationError

  def perform(document)
    Documents::ProcessDocument.new(document: document).call
  end
end
