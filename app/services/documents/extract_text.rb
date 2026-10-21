require "pdf-reader"
require "docx"
require "zip"

module Documents
  class ExtractText
    class Error < StandardError; end
    class UnsupportedPdfError < Error; end
    class UnsupportedFormatError < Error; end
    class EmptyTextError < Error; end
    class PageLimitExceededError < Error
      attr_reader :page_count

      def initialize(page_count:)
        @page_count = page_count

        super(
          "Tài liệu có #{page_count} trang, vượt giới hạn " \
            "#{MAX_PAGE_COUNT} trang"
        )
      end
    end

    MAX_PAGE_COUNT = 100
    PAGE_TARGET_CHARS = 3_000

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
    rescue Zip::Error => error
      raise UnsupportedFormatError,
        "Không thể đọc nội dung tệp Word: #{error.message}"
    end

    private

    attr_reader :document

    def validate_attachment!
      return if document.file.attached?

      raise ArgumentError, "Document phải có file đính kèm"
    end

    def extract_pages(file)
      case document_extension
      when "pdf"
        extract_pdf_pages(file)
      when "docx"
        extract_docx_pages(file)
      when "txt", "md"
        extract_plain_text_pages(file)
      else
        raise UnsupportedFormatError,
          "Định dạng tệp .#{document_extension} không được hỗ trợ"
      end
    end

    def document_extension
      document.extension.presence || File.extname(document.file.filename.to_s).delete(".").downcase
    end

    def extract_pdf_pages(file)
      reader = PDF::Reader.new(file)
      validate_page_count!(reader.page_count)

      pages = reader.pages.each_with_index.map do |page, index|
        Page.new(
          number: index + 1,
          text: normalize(page.text)
        )
      end

      if pages.none? { |p| p.text.present? }
        ai_ocr_text = normalize(Documents::GeminiOcr.new(file_path: file.path).call)
        if ai_ocr_text.present?
          return [ Page.new(number: 1, text: ai_ocr_text) ]
        end

        if Documents::OcrText.tesseract_available?
          tesseract_text = normalize(Documents::OcrText.new(file_path: file.path).call)
          if tesseract_text.present?
            return [ Page.new(number: 1, text: tesseract_text) ]
          end
        end
      end

      pages
    end

    def extract_docx_pages(file)
      docx_doc = Docx::Document.open(file.path)
      paragraphs = docx_doc.paragraphs.map do |p|
        p.text.to_s.dup.force_encoding(Encoding::UTF_8).strip
      end.reject(&:empty?)
      content = paragraphs.join("\n\n")

      if docx_doc.respond_to?(:tables) && docx_doc.tables.any?
        table_sections = docx_doc.tables.map do |table|
          table.rows.map do |row|
            row.cells.map { |c| c.text.to_s.dup.force_encoding(Encoding::UTF_8).strip }.join(" | ")
          end.join("\n")
        end.reject(&:empty?)

        content << "\n\n" << table_sections.join("\n\n") if table_sections.any?
      end

      normalized = normalize(content)
      pages_from_text(normalized)
    end

    def extract_plain_text_pages(file)
      raw_text = file.read.to_s.dup
      raw_text.force_encoding(Encoding::UTF_8)
      raw_text.sub!(/\A\xEF\xBB\xBF/, "") # Remove UTF-8 BOM if present

      normalized = normalize(raw_text)
      pages_from_text(normalized)
    end

    def pages_from_text(text)
      return [ Page.new(number: 1, text: text) ] if text.length <= PAGE_TARGET_CHARS

      lines = text.lines
      pages = []
      current_page_lines = []
      current_chars = 0

      lines.each do |line|
        current_page_lines << line
        current_chars += line.length

        if current_chars >= PAGE_TARGET_CHARS
          pages << Page.new(number: pages.size + 1, text: current_page_lines.join.strip)
          current_page_lines = []
          current_chars = 0
        end
      end

      if current_page_lines.any?
        pages << Page.new(number: pages.size + 1, text: current_page_lines.join.strip)
      end

      validate_page_count!(pages.size)
      pages
    end

    def validate_page_count!(page_count)
      return if page_count <= MAX_PAGE_COUNT

      raise PageLimitExceededError.new(page_count: page_count)
    end

    def validate_content!(pages)
      return if pages.any? { |page| page.text.present? }

      raise EmptyTextError,
        "Tài liệu không chứa nội dung văn bản có thể trích xuất"
    end

    def normalize(text)
      str = text.to_s.dup
      str.force_encoding(Encoding::UTF_8) if str.encoding != Encoding::UTF_8

      unless str.valid_encoding?
        str = str.encode(
          Encoding::UTF_8,
          invalid: :replace,
          undef: :replace,
          replace: ""
        )
      end

      str
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
