module Documents
  class RetryProcessing
    class Error < StandardError; end
    class InvalidStatusError < Error; end

    def initialize(document:)
      @document = document
    end

    def call
      document.with_lock do
        validate_status!

        document.update!(
          status: :pending,
          processing_version: document.processing_version + 1,
          error_code: nil,
          error_message: nil
        )
      end

      document
    end

    private

    attr_reader :document

    def validate_status!
      return if document.failed?

      raise InvalidStatusError,
        "Chỉ có thể xử lý lại tài liệu đang ở trạng thái thất bại."
    end
  end
end
