require "test_helper"
require "tempfile"

class Documents::UploadTest < ActiveSupport::TestCase
  test "uploads a real PDF" do
    uploaded_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf"
    )

    assert_difference("Document.count", 1) do
      document = upload(
        title: "Rails Guide",
        file: uploaded_file
      )

      assert document.persisted?
      assert document.pending?
      assert document.file.attached?
      assert_equal workspaces(:one), document.workspace
      assert_equal users(:one), document.uploaded_by
      assert_equal "application/pdf",
        document.file.content_type
    end
  ensure
    uploaded_file&.tempfile&.close!
  end

  test "rejects a fake PDF" do
    uploaded_file = uploaded_fixture(
      "fake.pdf",
      "application/pdf"
    )

    assert_no_difference(
      [
        "Document.count",
        "ActiveStorage::Blob.count"
      ]
    ) do
      document = upload(
        title: "Fake PDF",
        file: uploaded_file
      )

      assert_not document.persisted?
      assert_includes document.errors[:file],
        "không phải là tệp PDF hợp lệ"
    end
  ensure
    uploaded_file&.tempfile&.close!
  end

  test "requires a file" do
    assert_no_difference("Document.count") do
      document = upload(
        title: "Missing PDF",
        file: nil
      )

      assert_not document.persisted?
      assert_includes document.errors[:file],
        "phải được chọn"
    end
  end

  test "does not create blob when metadata is invalid" do
    uploaded_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf"
    )

    assert_no_difference(
      [
        "Document.count",
        "ActiveStorage::Blob.count"
      ]
    ) do
      document = upload(
        title: "",
        file: uploaded_file
      )

      assert_not document.persisted?
      assert_includes document.errors[:title],
        "can't be blank"
    end
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def upload(title:, file:)
    Documents::Upload.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      attributes: {
        title: title,
        file: file
      }
    ).call
  end

  def uploaded_fixture(filename, content_type)
    source = file_fixture(filename)
    extension = source.extname

    tempfile = Tempfile.new(
      [ source.basename(extension).to_s, extension ]
    )
    tempfile.binmode
    tempfile.write(source.binread)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end
end
