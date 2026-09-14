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
      .includes(:uploaded_by)
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

    # Support multiple files as well as single file
    raw_files = params.dig(:document, :files)
    files = Array(raw_files).compact_blank
    single_file = params.dig(:document, :file)
    files << single_file if single_file.present? && !files.include?(single_file)

    if files.blank?
      @document = candidate
      @document.errors.add(:file, "vui lòng chọn ít nhất một tệp PDF")
      @document_context = @document
      render :new, status: :unprocessable_entity and return
    end

    if files.size > 1
      # Multiple files upload flow
      successes = []
      failures = []

      files.each do |file|
        derived_title = File.basename(file.original_filename, ".*").tr("_-", " ").strip
        derived_title = "Tài liệu không tên" if derived_title.blank?

        doc = Documents::Upload.new(
          workspace: @workspace,
          uploaded_by: Current.user,
          attributes: { title: derived_title, file: file }
        ).call

        if doc.persisted?
          enqueue_processing(doc)
          successes << doc
        else
          error_msg = doc.errors.full_messages.to_sentence
          failures << "#{file.original_filename} (#{error_msg})"
        end
      end

      if failures.empty?
        redirect_to workspace_documents_path(@workspace),
          notice: "Đã tải lên thành công #{successes.size} tài liệu."
      elsif successes.any?
        redirect_to workspace_documents_path(@workspace),
          alert: "Đã tải lên #{successes.size} tài liệu thành công. Có #{failures.size} tệp lỗi: #{failures.join(', ')}."
      else
        @document = candidate
        @document_context = @document
        flash.now[:alert] = "Tải tài liệu thất bại: #{failures.join(', ')}."
        render :new, status: :unprocessable_entity
      end
    else
      # Single file upload flow
      file = files.first
      custom_title = params.dig(:document, :title).presence || File.basename(file.original_filename, ".*").tr("_-", " ").strip

      @document = Documents::Upload.new(
        workspace: @workspace,
        uploaded_by: Current.user,
        attributes: { title: custom_title, file: file }
      ).call

      if @document.persisted?
        enqueue_processing(@document)

        redirect_to workspace_document_path(
          @workspace,
          @document
        ), notice: "Tài liệu đã được tải lên thành công."
      else
        @document_context = @document
        render :new, status: :unprocessable_entity
      end
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
    enqueue_processing(@document)

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

  def enqueue_processing(document)
    ProcessDocumentJob.perform_later(
      document.id,
      document.processing_version
    )
  end

  def document_params
    params.fetch(:document, {}).permit(:title, :file, files: [])
  end
end
