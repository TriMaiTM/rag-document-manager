module Documents
  class Upload
    def initialize(workspace:, uploaded_by:, attributes:)
      @workspace = workspace
      @uploaded_by = uploaded_by
      @title = attributes[:title]
      @file = attributes[:file]
    end

    def call
      document = workspace.documents.new(
        uploaded_by: uploaded_by,
        title: title
      )

      return save_without_file(document) unless file
      return document unless metadata_valid?(document)

      unless actual_pdf?
        document.errors.add(
          :file,
          "không phải là tệp PDF hợp lệ"
        )
        return document
      end

      attach_file(document)
      document.save
      document
    end

    private

    attr_reader :workspace, :uploaded_by, :title, :file

    def save_without_file(document)
      document.save
      document
    end

    def metadata_valid?(document)
      document.valid?
      document.errors.delete(:file)
      document.errors.empty?
    end

    def actual_pdf?
      return false unless uploaded_file?

      detected_content_type == Document::PDF_CONTENT_TYPE &&
        pdf_signature?
    rescue IOError, SystemCallError
      false
    end

    def uploaded_file?
      file.respond_to?(:tempfile) && file.tempfile.present?
    end

    def detected_content_type
      rewind_file

      Marcel::MimeType.for(
        file.tempfile,
        name: file.original_filename
      )
    ensure
      rewind_file
    end

    def pdf_signature?
      rewind_file
      file.tempfile.read(5) == "%PDF-"
    ensure
      rewind_file
    end

    def attach_file(document)
      rewind_file

      document.file.attach(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: Document::PDF_CONTENT_TYPE
      )
    end

    def rewind_file
      file&.tempfile&.rewind
    end
  end
end
