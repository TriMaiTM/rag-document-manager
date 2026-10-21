require "test_helper"
require "stringio"
require "minitest/mock"

class DocumentTest < ActiveSupport::TestCase
  setup do
    @document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Ruby on Rails Guide"
    )

    @document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "rails-guide.pdf",
      content_type: "application/pdf"
    )
  end

  test "is valid with a PDF attachment" do
    assert @document.valid?
  end

  test "requires a title" do
    @document.title = ""

    assert_not @document.valid?
    assert_includes @document.errors[:title], "can't be blank"
  end

  test "requires a file" do
    @document.file.detach

    assert_not @document.valid?
    assert_includes @document.errors[:file], "phải được chọn"
  end

  test "requires PDF content type" do
    @document.file.attach(
      io: StringIO.new("plain text"),
      filename: "notes.pdf",
      content_type: "text/plain"
    )

    assert_not @document.valid?
    assert_includes @document.errors[:file],
      "phải có content type application/pdf"
  end

  test "requires valid extension" do
    @document.file.attach(
      io: StringIO.new("binary content"),
      filename: "document.exe",
      content_type: "application/octet-stream"
    )

    assert_not @document.valid?
    assert_includes @document.errors[:file],
      "phải có phần mở rộng .pdf, .docx, .txt hoặc .md"
  end

  test "is valid with a DOCX attachment" do
    @document.file.attach(
      io: file_fixture("sample.docx").open,
      filename: "sample.docx",
      content_type: Document::DOCX_CONTENT_TYPE
    )

    assert @document.valid?
    assert @document.docx?
    assert_not @document.pdf?
    assert_equal "docx", @document.extension
  end

  test "is valid with a TXT attachment" do
    @document.file.attach(
      io: file_fixture("sample.txt").open,
      filename: "sample.txt",
      content_type: "text/plain"
    )

    assert @document.valid?
    assert @document.text_based?
    assert_not @document.pdf?
    assert_equal "txt", @document.extension
  end

  test "is valid with a Markdown attachment" do
    @document.file.attach(
      io: file_fixture("sample.md").open,
      filename: "sample.md",
      content_type: "text/markdown"
    )

    assert @document.valid?
    assert @document.markdown?
    assert @document.text_based?
    assert_not @document.docx?
    assert_equal "md", @document.extension
  end

  test "rejects files larger than twenty megabytes" do
    @document.file.blob.stub(
      :byte_size,
      Document::MAX_FILE_SIZE + 1
    ) do
      assert_not @document.valid?
      assert_includes @document.errors[:file],
        "không được lớn hơn 20 MB"
    end
  end

  test "only accepts known statuses" do
    @document.status = "unknown"

    assert_not @document.valid?
    assert_includes @document.errors[:status],
      "is not included in the list"
  end

  test "keeps lifecycle timestamps consistent with status" do
    @document.save!

    @document.update!(status: :processing)
    assert_predicate @document.processing_started_at, :present?
    assert_nil @document.completed_at
    assert_nil @document.failed_at

    @document.update!(status: :completed)
    assert_predicate @document.completed_at, :present?
    assert_nil @document.failed_at
  end

  test "rejects lifecycle timestamps that do not match status" do
    @document.save!
    @document.update!(status: :processing)
    @document.completed_at = Time.current

    assert_not @document.valid?
    assert_includes @document.errors[:status],
      "không khớp với các mốc thời gian xử lý"
  end

  test "allows a positive page count or an unknown page count" do
    @document.page_count = nil
    assert_predicate @document, :valid?

    @document.page_count = 10
    assert_predicate @document, :valid?

    @document.page_count = 0
    assert_not @document.valid?
  end

  test "validates SHA-256 format" do
    @document.content_sha256 = "not-a-sha256"

    assert_not @document.valid?
    assert_includes @document.errors[:content_sha256],
      "is the wrong length (should be 64 characters)"
  end

  test "requires a workspace-scoped unique checksum" do
    checksum = "a" * 64
    @document.content_sha256 = checksum
    @document.save!

    duplicate = Document.new(
      workspace: @document.workspace,
      uploaded_by: @document.uploaded_by,
      title: "Duplicate",
      content_sha256: checksum
    )
    duplicate.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "duplicate.pdf",
      content_type: "application/pdf"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:content_sha256],
      "has already been taken"
  end
end
