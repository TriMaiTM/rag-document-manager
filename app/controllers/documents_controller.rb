class DocumentsController < ApplicationController
  before_action :set_workspace
  before_action :set_document,
    only: [ :show, :download, :destroy ]

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
