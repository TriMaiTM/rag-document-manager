require "pdf-reader"

module Documents
  class ExtractText
    class Error < StandardError; end
    class UnsupportedPdfError < Error; end
    class EmptyTextError < Error; end
    class PageLimitExceededError < Error
      attr_reader :page_count

      def initialize(page_count:)
        @page_count = page_count

        super(
          "PDF có #{page_count} trang, vượt giới hạn " \
            "#{MAX_PAGE_COUNT} trang"
        )
      end
    end

    MAX_PAGE_COUNT = 100

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
      validate_page_count!(reader.page_count)

      reader.pages.each_with_index.map do |page, index|
        Page.new(
          number: index + 1,
          text: normalize(page.text)
        )
      end
    end

    def validate_page_count!(page_count)
      return if page_count <= MAX_PAGE_COUNT

      raise PageLimitExceededError.new(page_count: page_count)
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
