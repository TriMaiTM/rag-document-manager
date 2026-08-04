module Documents
  class RetryProcessing
    class Error < StandardError; end
    class InvalidStatusError < Error; end

    def initialize(document:)
      @document = document
    end

    def call
      lifecycle.retry!
    rescue Documents::Lifecycle::InvalidTransitionError
      raise InvalidStatusError,
        "Chỉ có thể xử lý lại tài liệu đang ở trạng thái thất bại."
    end

    private

    attr_reader :document

    def lifecycle
      @lifecycle ||= Documents::Lifecycle.new(document: document)
    end
  end
end
