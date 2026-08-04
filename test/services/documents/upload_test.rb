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
      assert_equal(
        Digest::SHA256.file(file_fixture("sample.pdf")).hexdigest,
        document.content_sha256
      )
      assert_equal file_fixture("sample.pdf").size,
        document.file.byte_size
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

  test "rejects the same file with a different name in one workspace" do
    original_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf"
    )
    renamed_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf",
      upload_filename: "renamed-guide.pdf"
    )
    original = upload(
      title: "Original",
      file: original_file
    )

    assert original.persisted?

    assert_no_difference(
      [
        "Document.count",
        "ActiveStorage::Blob.count"
      ]
    ) do
      duplicate = upload(
        title: "Renamed duplicate",
        file: renamed_file
      )

      assert_not duplicate.persisted?
      assert_includes duplicate.errors[:file],
        Documents::Upload::DUPLICATE_FILE_ERROR
    end
  ensure
    original_file&.tempfile&.close!
    renamed_file&.tempfile&.close!
  end

  test "allows the same file in a different workspace" do
    first_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf"
    )
    second_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf",
      upload_filename: "same-content.pdf"
    )

    assert_difference("Document.count", 2) do
      @first_document = upload(
        title: "Workspace one copy",
        file: first_file
      )
      @second_document = upload(
        title: "Workspace two copy",
        file: second_file,
        workspace: workspaces(:two),
        uploaded_by: users(:two)
      )
    end

    assert_equal @first_document.content_sha256,
      @second_document.content_sha256
  ensure
    first_file&.tempfile&.close!
    second_file&.tempfile&.close!
  end

  test "handles a concurrent duplicate without leaving an orphan blob" do
    uploaded_file = uploaded_fixture(
      "sample.pdf",
      "application/pdf"
    )
    workspace = workspaces(:one)
    documents = workspace.documents
    candidate = documents.new(
      uploaded_by: users(:one),
      title: "Concurrent duplicate"
    )
    existence_checks = 0
    exists_stub = lambda do |*_arguments|
      existence_checks += 1
      existence_checks > 1
    end
    save_stub = lambda do |**_arguments|
      raise ActiveRecord::RecordNotUnique,
        "index_documents_on_workspace_and_content_sha256"
    end

    assert_no_difference(
      [
        "Document.count",
        "ActiveStorage::Blob.count"
      ]
    ) do
      candidate.stub(:save, save_stub) do
        documents.stub(:new, candidate) do
          documents.stub(:exists?, exists_stub) do
            result = Documents::Upload.new(
              workspace: workspace,
              uploaded_by: users(:one),
              attributes: {
                title: "Concurrent duplicate",
                file: uploaded_file
              }
            ).call

            assert_not result.persisted?
            assert_includes result.errors[:file],
              Documents::Upload::DUPLICATE_FILE_ERROR
          end
        end
      end
    end

    assert_equal 2, existence_checks
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def upload(
    title:,
    file:,
    workspace: workspaces(:one),
    uploaded_by: users(:one)
  )
    Documents::Upload.new(
      workspace: workspace,
      uploaded_by: uploaded_by,
      attributes: {
        title: title,
        file: file
      }
    ).call
  end

  def uploaded_fixture(
    filename,
    content_type,
    upload_filename: filename
  )
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
      filename: upload_filename,
      type: content_type
    )
  end
end
