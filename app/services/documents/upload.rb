require "digest"

module Documents
  class Upload
    DUPLICATE_FILE_ERROR =
      "đã tồn tại trong Workspace này"
    HASH_BUFFER_SIZE = 1.megabyte

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

      checksum = content_sha256
      if duplicate_content?(checksum)
        add_duplicate_error(document)
        return document
      end

      document.content_sha256 = checksum
      attach_file(document)
      document.save
      normalize_duplicate_validation_error(document)
      document
    rescue ActiveRecord::RecordNotUnique
      raise unless duplicate_content?(document.content_sha256)

      purge_unpersisted_file(document)
      add_duplicate_error(document)
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

    def content_sha256
      digest = Digest::SHA256.new
      rewind_file

      while (buffer = file.tempfile.read(HASH_BUFFER_SIZE))
        digest.update(buffer)
      end

      digest.hexdigest
    ensure
      rewind_file
    end

    def duplicate_content?(checksum)
      return false if checksum.blank?

      workspace.documents.exists?(content_sha256: checksum)
    end

    def normalize_duplicate_validation_error(document)
      return unless document.errors.added?(:content_sha256, :taken)

      document.errors.delete(:content_sha256)
      purge_unpersisted_file(document)
      add_duplicate_error(document)
    end

    def purge_unpersisted_file(document)
      return if document.persisted?
      return unless document.file.attached?

      document.file.purge
    end

    def add_duplicate_error(document)
      document.errors.add(:file, DUPLICATE_FILE_ERROR)
    end

    def rewind_file
      file&.tempfile&.rewind
    end
  end
end
