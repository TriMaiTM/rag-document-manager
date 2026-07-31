require "pdf-reader"

module Documents
  class ExtractText
    class Error < StandardError; end
    class UnsupportedPdfError < Error; end
    class EmptyTextError < Error; end

    Page = Data.define(:number, :text)

    def initialize(document:)
      @document = document
    end

    def call
      validate_attachment!

      pages = document.file.open do |file|
        extract_pages(file)
      end

      validate_content!(pages)
      pages
    rescue PDF::Reader::MalformedPDFError,
      PDF::Reader::UnsupportedFeatureError => error
      raise UnsupportedPdfError,
        "Không thể đọc nội dung PDF: #{error.message}"
    end

    private

    attr_reader :document

    def validate_attachment!
      return if document.file.attached?

      raise ArgumentError, "Document phải có file đính kèm"
    end

    def extract_pages(file)
      reader = PDF::Reader.new(file)

      reader.pages.each_with_index.map do |page, index|
        Page.new(
          number: index + 1,
          text: normalize(page.text)
        )
      end
    end

    def validate_content!(pages)
      return if pages.any? { |page| page.text.present? }

      raise EmptyTextError,
        "PDF không chứa nội dung văn bản có thể trích xuất"
    end

    def normalize(text)
      text
        .encode(
          Encoding::UTF_8,
          invalid: :replace,
          undef: :replace,
          replace: ""
        )
        .gsub("\r\n", "\n")
        .gsub("\r", "\n")
        .lines
        .map { |line| line.gsub(/[[:blank:]]+/, " ").strip }
        .join("\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end
  end
end
