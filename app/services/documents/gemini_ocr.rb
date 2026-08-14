require "base64"

module Documents
  class GeminiOcr
    class Error < StandardError; end

    PROMPT = <<~TEXT.freeze
      Hãy trích xuất toàn bộ nội dung văn bản, câu hỏi và công thức toán học có trong tệp tài liệu này thành văn bản thuần túy.
      Giữ nguyên nội dung, các công thức toán học và cấu trúc các bài học/câu hỏi. Không tự ý tóm tắt hay cắt bớt.
    TEXT

    def initialize(file_path:, mime_type: "application/pdf")
      @file_path = file_path.to_s
      @mime_type = mime_type.presence || "application/pdf"
    end

    def call
      return "" unless File.exist?(file_path)

      base64_data = Base64.strict_encode64(File.binread(file_path))
      client = Ai::GeminiClient.new

      response = client.generate_content_with_inline_data(
        prompt: PROMPT,
        mime_type: mime_type,
        base64_data: base64_data
      )

      response.text.to_s.strip
    rescue StandardError => error
      Rails.logger.warn("Gemini Vision OCR failed: #{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}")
      ""
    end

    private

    attr_reader :file_path, :mime_type
  end
end
