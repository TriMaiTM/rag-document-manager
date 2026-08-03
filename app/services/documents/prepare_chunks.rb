module Documents
  class PrepareChunks
    class Error < StandardError; end
    class InvalidStatusError < Error; end
    class EmptyChunksError < Error; end
    class StaleProcessingVersionError < Error; end

    PROCESSABLE_STATUSES = %w[
      pending
      processing
      failed
    ].freeze

    Result = Data.define(
      :document,
      :chunks,
      :processing_version
    )

    def initialize(
      document:,
      extractor: Documents::ExtractText,
      chunker: Documents::ChunkText
    )
      @document = document
      @extractor = extractor
      @chunker = chunker
    end

    def call
      processing_version = nil

      processing_version = start_processing!
      pages = extract_pages
      chunks = build_chunks(pages)

      validate_chunks!(chunks)

      saved_chunks = replace_chunks!(
        chunks,
        processing_version
      )

      Result.new(
        document: document,
        chunks: saved_chunks,
        processing_version: processing_version
      )
    rescue StandardError => error
      mark_failed!(error, processing_version)
      raise
    end

    private

    attr_reader :document, :extractor, :chunker

    def start_processing!
      document.with_lock do
        validate_status!

        document.update!(
          status: :processing,
          error_code: nil,
          error_message: nil
        )

        document.processing_version
      end
    end

    def validate_status!
      return if PROCESSABLE_STATUSES.include?(
        document.status
      )

      raise InvalidStatusError,
        "Không thể xử lý document ở trạng thái " \
        "#{document.status}"
    end

    def extract_pages
      extractor.new(
        document: document
      ).call
    end

    def build_chunks(pages)
      chunker.new(
        pages: pages
      ).call.to_a
    end

    def validate_chunks!(chunks)
      return if chunks.any?

      raise EmptyChunksError,
        "Không tạo được chunk nào từ document"
    end

    def replace_chunks!(chunks, processing_version)
      document.with_lock do
        validate_processing_version!(
          processing_version
        )

        document.document_chunks
          .where(
            processing_version: processing_version
          )
          .delete_all

        chunks.map do |chunk|
          document.document_chunks.create!(
            content: chunk.content,
            page_number: chunk.page_number,
            position: chunk.position,
            processing_version: processing_version
          )
        end
      end
    end

    def validate_processing_version!(expected_version)
      return if document.processing_version ==
        expected_version

      raise StaleProcessingVersionError,
        "Document đã bắt đầu một lượt xử lý mới hơn"
    end

    def mark_failed!(error, processing_version)
      return unless processing_version

      document.with_lock do
        return unless document.processing_version ==
          processing_version

        document.update_columns(
          status: "failed",
          error_code: error_code(error),
          error_message: safe_error_message(error),
          updated_at: Time.current
        )
      end
    end

    def error_code(error)
      error.class.name
        .demodulize
        .underscore
    end

    def safe_error_message(error)
      error.message
        .to_s
        .truncate(1_000)
    end
  end
end
