require "rtesseract"

module Documents
  class OcrText
    class Error < StandardError; end
    class OcrNotAvailableError < Error; end

    def initialize(file_path:, lang: "vie+eng")
      @file_path = file_path
      @lang = lang
    end

    def call
      validate_tesseract_installed!

      ocr = RTesseract.new(file_path.to_s, lang: lang)
      ocr.to_s.to_s.strip
    rescue RTesseract::Error => error
      Rails.logger.warn("RTesseract OCR failed: #{error.message}")
      ""
    end

    def self.tesseract_available?
      system("which tesseract > /dev/null 2>&1")
    end

    private

    attr_reader :file_path, :lang

    def validate_tesseract_installed!
      return if self.class.tesseract_available?

      raise OcrNotAvailableError,
        "Hệ thống máy chủ chưa cài đặt Tesseract OCR (tesseract-ocr)"
    end
  end
end
