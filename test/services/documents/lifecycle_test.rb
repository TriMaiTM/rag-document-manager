require "test_helper"

class Documents::LifecycleTest < ActiveSupport::TestCase
  setup do
    @document = build_document
    @now = Time.zone.local(2026, 8, 4, 10, 30, 0)
    @lifecycle = Documents::Lifecycle.new(
      document: @document,
      clock: -> { @now }
    )
  end

  teardown do
    @document.file.purge if @document.file.attached?
  end

  test "moves a pending document through processing and completion" do
    version = @lifecycle.start_processing!

    assert_equal 1, version
    assert @document.processing?
    assert_equal @now, @document.processing_started_at
    assert_nil @document.completed_at
    assert_nil @document.failed_at

    @lifecycle.complete!(expected_processing_version: version)

    assert @document.completed?
    assert_equal @now, @document.completed_at
    assert_nil @document.failed_at
  end

  test "records a safe failure and preserves its processing start" do
    version = @lifecycle.start_processing!
    started_at = @document.processing_started_at
    error = RuntimeError.new("Gemini unavailable")

    assert @lifecycle.fail!(
      error: error,
      expected_processing_version: version
    )

    @document.reload
    assert @document.failed?
    assert_equal started_at, @document.processing_started_at
    assert_equal @now, @document.failed_at
    assert_nil @document.completed_at
    assert_equal "runtime_error", @document.error_code
    assert_equal "Gemini unavailable", @document.error_message
  end

  test "does not let an old worker fail a newer processing version" do
    version = @lifecycle.start_processing!
    @document.update_column(:processing_version, version + 1)

    result = @lifecycle.fail!(
      error: RuntimeError.new("Late failure"),
      expected_processing_version: version
    )

    assert_equal false, result
    assert @document.reload.processing?
    assert_nil @document.failed_at
  end

  test "rejects starting a completed document" do
    @document.update!(status: :completed)

    assert_raises(Documents::Lifecycle::InvalidTransitionError) do
      @lifecycle.start_processing!
    end
  end

  private

  def build_document
    document = Document.new(
      workspace: workspaces(:one),
      uploaded_by: users(:one),
      title: "Lifecycle test"
    )
    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "lifecycle.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    document.save!
    document
  end
end
