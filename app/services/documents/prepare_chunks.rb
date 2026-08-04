module Documents
  class PrepareChunks
    class Error < StandardError; end
    class InvalidStatusError < Error; end
    class EmptyChunksError < Error; end
    class StaleProcessingVersionError < Error; end
    class ChunkLimitExceededError < Error
      attr_reader :chunk_count

      def initialize(chunk_count:)
        @chunk_count = chunk_count

        super(
          "Tài liệu tạo ra #{chunk_count} chunks, vượt giới hạn " \
            "#{MAX_CHUNK_COUNT} chunks"
        )
      end
    end

    MAX_CHUNK_COUNT = 500

    Result = Data.define(
      :document,
      :chunks,
      :processing_version,
      :page_count
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
      record_page_count!(pages.size, processing_version)
      chunks = build_chunks(pages)

      validate_chunks!(chunks)

      saved_chunks = replace_chunks!(
        chunks,
        processing_version
      )

      Result.new(
        document: document,
        chunks: saved_chunks,
        processing_version: processing_version,
        page_count: pages.size
      )
    rescue StandardError => error
      mark_failed!(error, processing_version)
      raise
    end

    private

    attr_reader :document, :extractor, :chunker

    def start_processing!
      lifecycle.start_processing!
    rescue Documents::Lifecycle::InvalidTransitionError => error
      raise InvalidStatusError, error.message
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
      if chunks.empty?
        raise EmptyChunksError,
          "Không tạo được chunk nào từ document"
      end

      return if chunks.size <= MAX_CHUNK_COUNT

      raise ChunkLimitExceededError.new(
        chunk_count: chunks.size
      )
    end

    def record_page_count!(page_count, processing_version)
      document.with_lock do
        validate_processing_version!(processing_version)

        document.update!(page_count: page_count)
      end
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

      attributes = {}
      if error.respond_to?(:page_count)
        attributes[:page_count] = error.page_count
      end

      lifecycle.fail!(
        error: error,
        expected_processing_version: processing_version,
        attributes: attributes
      )
    end

    def lifecycle
      @lifecycle ||= Documents::Lifecycle.new(document: document)
    end
  end
end
