require "test_helper"

class Documents::RetryProcessingTest < ActiveSupport::TestCase
  setup do
    @document = create_document
    @document.update!(
      status: :failed,
      error_code: "network_error",
      error_message: "Request timed out"
    )
    @old_chunk = @document.document_chunks.create!(
      content: "Old processing content",
      page_number: 1,
      position: 1,
      processing_version: @document.processing_version
    )
  end

  teardown do
    @document.file.purge if @document.file.attached?
  end

  test "starts a new processing version and clears the previous error" do
    result = Documents::RetryProcessing.new(document: @document).call

    assert_same @document, result
    assert @document.pending?
    assert_equal 2, @document.processing_version
    assert_nil @document.error_code
    assert_nil @document.error_message
    assert_predicate @old_chunk.reload, :persisted?
  end

  test "rejects a document that has not failed" do
    @document.update!(status: :completed)

    assert_raises(Documents::RetryProcessing::InvalidStatusError) do
      Documents::RetryProcessing.new(document: @document).call
    end

    assert @document.reload.completed?
    assert_equal 1, @document.processing_version
  end

  private

  def create_document
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Retry processing"
    )
    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "retry-processing.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    document.save!
    document
  end
end
