class ProcessDocumentJob < ApplicationJob
  queue_as :documents

  discard_on ActiveJob::DeserializationError

  def perform(document)
    Documents::PrepareChunks.new(document: document).call
    Documents::EmbedChunks.new(document: document).call
  end
end
