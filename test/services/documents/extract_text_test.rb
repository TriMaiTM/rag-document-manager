require "test_helper"
require "prawn"
require "tempfile"

class Documents::ExtractTextTest < ActiveSupport::TestCase
  setup do
    @documents = []
    @tempfiles = []
  end

  teardown do
    @documents.each do |document|
      document.file.purge if document.file.attached?
    end

    @tempfiles.each(&:close!)
  end

  test "extracts text and preserves page numbers" do
    pdf = create_pdf(
      "Introduction to Rails.",
      "Active Record manages database records."
    )
    document = create_document_with(pdf)

    pages = extract(document)

    assert_equal 2, pages.size
    assert_equal [ 1, 2 ], pages.map(&:number)

    assert_includes pages.first.text,
      "Introduction to Rails."

    assert_includes pages.second.text,
      "Active Record manages database records."
  end

  test "preserves blank pages" do
    pdf = create_pdf(
      "Visible content.",
      nil,
      "Final content."
    )
    document = create_document_with(pdf)

    pages = extract(document)

    assert_equal 3, pages.size
    assert_equal [ 1, 2, 3 ], pages.map(&:number)
    assert_equal "", pages.second.text
  end

  test "rejects a PDF without extractable text" do
    pdf = create_pdf(nil)
    document = create_document_with(pdf)

    assert_raises(
      Documents::ExtractText::EmptyTextError
    ) do
      extract(document)
    end
  end

  test "rejects a malformed PDF" do
    pdf = create_malformed_pdf
    document = create_document_with(pdf)

    assert_raises(
      Documents::ExtractText::UnsupportedPdfError
    ) do
      extract(document)
    end
  end

  test "rejects a PDF that exceeds the page limit" do
    pdf = create_pdf(
      *Array.new(
        Documents::ExtractText::MAX_PAGE_COUNT + 1,
        "Page content"
      )
    )
    document = create_document_with(pdf)

    error = assert_raises(
      Documents::ExtractText::PageLimitExceededError
    ) do
      extract(document)
    end

    assert_equal Documents::ExtractText::MAX_PAGE_COUNT + 1,
      error.page_count
  end

  test "requires an attached file" do
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Missing file"
    )

    assert_raises(ArgumentError) do
      extract(document)
    end
  end

  private

  def extract(document)
    Documents::ExtractText.new(
      document: document
    ).call
  end

  def create_document_with(file)
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Extraction test"
    )

    document.file.attach(
      io: file,
      filename: "extraction-test.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )

    document.save!
    @documents << document
    document
  end

  def create_pdf(*page_contents)
    tempfile = new_tempfile

    pdf = Prawn::Document.new

    page_contents.each_with_index do |content, index|
      pdf.start_new_page unless index.zero?
      pdf.text(content) if content.present?
    end

    tempfile.write(pdf.render)
    tempfile.rewind
    tempfile
  end

  def create_malformed_pdf
    tempfile = new_tempfile
    tempfile.write("%PDF-1.7\nThis is not a valid PDF")
    tempfile.rewind
    tempfile
  end

  def new_tempfile
    tempfile = Tempfile.new(
      [ "document-extraction", ".pdf" ]
    )
    tempfile.binmode

    @tempfiles << tempfile
    tempfile
  end
end
