require "test_helper"

class DocumentsControllerTest <
  ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs

    @workspace = workspaces(:one)
    @document = create_document(
      @workspace,
      users(:one),
      "Rails Guide"
    )

    sign_in_as users(:one)
  end

  test "requires authentication" do
    sign_out

    get workspace_documents_url(@workspace)

    assert_redirected_to new_user_session_url
  end

  test "owner views document list" do
    get workspace_documents_url(@workspace)

    assert_response :success
    assert_select "h1", "Tài liệu"
    assert_select "a", @document.title
    assert_select "a", "Tải tài liệu lên"
  end

  test "owner views document details" do
    get workspace_document_url(
      @workspace,
      @document
    )

    assert_response :success
    assert_select "h1", @document.title
    assert_select "a", "Tải PDF xuống"
    assert_select "button", "Xóa tài liệu"
  end

  test "owner uploads a real PDF" do
    pdf = file_fixture_upload(
      "sample.pdf",
      "application/pdf"
    )

    assert_enqueued_jobs 1, only: ProcessDocumentJob do
      assert_difference("Document.count", 1) do
        post workspace_documents_url(@workspace),
          params: {
            document: {
              title: "Uploaded PDF",
              file: pdf
            }
          }
      end
    end

    document = @workspace
      .documents
      .order(:created_at)
      .last

    assert document.pending?
    assert document.file.attached?
    assert_equal users(:one), document.uploaded_by

    assert_redirected_to workspace_document_url(
      @workspace,
      document
    )
  end

  test "rejects a fake PDF" do
    fake_pdf = file_fixture_upload(
      "fake.pdf",
      "application/pdf"
    )

    assert_no_difference("Document.count") do
      post workspace_documents_url(@workspace),
        params: {
          document: {
            title: "Fake PDF",
            file: fake_pdf
          }
        }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
    assert_select "li",
      /không phải là tệp PDF hợp lệ/
  end

  test "requires a file" do
    assert_no_difference("Document.count") do
      post workspace_documents_url(@workspace),
        params: {
          document: {
            title: "Missing PDF"
          }
        }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "downloads document through authorized controller" do
    get download_workspace_document_url(
      @workspace,
      @document
    )

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(
      /attachment/,
      response.headers["Content-Disposition"]
    )
    assert_equal(
      file_fixture("sample.pdf").binread,
      response.body
    )
  end

  test "owner destroys document" do
    assert_difference("Document.count", -1) do
      delete workspace_document_url(
        @workspace,
        @document
      )
    end

    assert_redirected_to workspace_documents_url(
      @workspace
    )
  end

  test "member can read and download but cannot manage" do
    sign_out
    sign_in_as users(:two)

    get workspace_documents_url(@workspace)
    assert_response :success
    assert_select "a", text: "Tải tài liệu lên", count: 0

    get workspace_document_url(
      @workspace,
      @document
    )
    assert_response :success
    assert_select "button", text: "Xóa tài liệu", count: 0

    get download_workspace_document_url(
      @workspace,
      @document
    )
    assert_response :success

    get new_workspace_document_url(@workspace)
    assert_response :forbidden

    assert_no_difference("Document.count") do
      post workspace_documents_url(@workspace),
        params: {
          document: {
            title: "Forbidden upload",
            file: file_fixture_upload(
              "sample.pdf",
              "application/pdf"
            )
          }
        }
    end
    assert_response :forbidden

    assert_no_difference("Document.count") do
      delete workspace_document_url(
        @workspace,
        @document
      )
    end
    assert_response :forbidden
  end

  test "outsider receives not found" do
    sign_out
    sign_in_as users(:four)

    get workspace_documents_url(@workspace)

    assert_response :not_found
  end

  test "cannot access document through another workspace" do
    second_document = create_document(
      workspaces(:two),
      users(:two),
      "Private Document"
    )

    sign_out
    sign_in_as users(:two)

    get workspace_document_url(
      @workspace,
      second_document
    )

    assert_response :not_found
  end

  private

  def create_document(workspace, uploader, title)
    document = workspace.documents.new(
      uploaded_by: uploader,
      title: title
    )

    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "#{title.parameterize}.pdf",
      content_type: "application/pdf"
    )

    document.save!
    document
  end
end
