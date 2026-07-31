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

  test "requires PDF extension" do
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "document.txt",
      content_type: "application/pdf"
    )

    assert_not @document.valid?
    assert_includes @document.errors[:file],
      "phải có phần mở rộng .pdf"
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
end
