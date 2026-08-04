class DocumentsController < ApplicationController
  before_action :set_workspace
  before_action :set_document,
    only: [
      :show,
      :download,
      :processing_status,
      :retry_processing,
      :destroy
    ]

  after_action :verify_authorized

  def index
    @document_context = document_context
    authorize @document_context

    @documents = @workspace
      .documents
      .with_attached_file
      .order(created_at: :desc)
  end

  def show
    authorize @document
  end

  def new
    @document = document_context
    authorize @document
  end

  def create
    candidate = document_context
    authorize candidate

    @document = Documents::Upload.new(
      workspace: @workspace,
      uploaded_by: Current.user,
      attributes: document_params
    ).call

    if @document.persisted?
      ProcessDocumentJob.perform_later(@document.id)

      redirect_to workspace_document_path(
        @workspace,
        @document
      ), notice: "Tài liệu đã được tải lên thành công."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def download
    authorize @document

    send_data @document.file.download,
      filename: @document.file.filename.to_s,
      type: Document::PDF_CONTENT_TYPE,
      disposition: "attachment"
  end

  def processing_status
    authorize @document
    expires_now

    render json: {
      status: @document.status,
      label: helpers.document_status_label(@document),
      terminal: @document.completed? || @document.failed?,
      updated_at: @document.updated_at.iso8601,
      processing_started_at:
        @document.processing_started_at&.iso8601,
      completed_at: @document.completed_at&.iso8601,
      failed_at: @document.failed_at&.iso8601
    }
  end

  def retry_processing
    authorize @document

    Documents::RetryProcessing.new(document: @document).call
    ProcessDocumentJob.perform_later(@document.id)

    redirect_to workspace_document_path(@workspace, @document),
      notice: "Tài liệu đã được đưa vào hàng đợi xử lý lại.",
      status: :see_other
  rescue Documents::RetryProcessing::InvalidStatusError => error
    redirect_to workspace_document_path(@workspace, @document),
      alert: error.message,
      status: :see_other
  end

  def destroy
    authorize @document
    @document.destroy!

    redirect_to workspace_documents_path(@workspace),
      notice: "Tài liệu đã được xóa.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = policy_scope(Workspace).find(
      params[:workspace_id]
    )

    Current.workspace = @workspace
  end

  def set_document
    @document = @workspace
      .documents
      .with_attached_file
      .find(params[:id])
  end

  def document_context
    @workspace.documents.new(uploaded_by: Current.user)
  end

  def document_params
    params.expect(document: [ :title, :file ])
  end
end
