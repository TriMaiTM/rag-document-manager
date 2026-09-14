require "fileutils"
require "json"

module Admin
  class EvaluationsController < BaseController
    REPORTS_DIR = Rails.root.join("storage", "evaluations")
    FILENAME_PATTERN = /\Arag_evaluation_\d{14}\.json\z/

    def index
      @workspaces = Workspace.order(:name)
      @default_k = Rag::EvaluateRetrieval::DEFAULT_LIMIT
      @default_max_distance = Rails.application.config.x.semantic_search.max_cosine_distance || 0.40
      @dataset_path = Rails.root.join("config", "rag_evaluation.yml")
      @dataset_exists = File.exist?(@dataset_path)

      if @dataset_exists
        begin
          @dataset_cases = Rag::EvaluationDataset.new(path: @dataset_path.to_s).call
        rescue StandardError => e
          @dataset_error = e.message
          @dataset_cases = []
        end
      else
        @dataset_cases = []
      end

      @reports = load_reports_list

      selected_id = params[:report_id] || @reports.first&.dig(:filename)
      if selected_id.present? && valid_filename?(selected_id)
        @selected_report = load_report_file(selected_id)
      end
    end

    def create
      workspace = Workspace.find(params[:workspace_id])
      k = params[:k].presence ? Integer(params[:k]) : Rag::EvaluateRetrieval::DEFAULT_LIMIT
      max_distance = params[:max_cosine_distance].presence ? Float(params[:max_cosine_distance]) : (Rails.application.config.x.semantic_search.max_cosine_distance || 0.40)
      dataset_file = Rails.root.join("config", "rag_evaluation.yml")

      unless File.exist?(dataset_file)
        return redirect_to admin_evaluations_path, alert: "Không tìm thấy file cấu hình tập kiểm thử config/rag_evaluation.yml."
      end

      cases = Rag::EvaluationDataset.new(path: dataset_file.to_s).call
      if cases.empty?
        return redirect_to admin_evaluations_path, alert: "Tập kiểm thử không có câu hỏi nào để đánh giá."
      end

      report = Rag::EvaluateRetrieval.new(
        workspace: workspace,
        cases: cases,
        limit: k,
        max_cosine_distance: max_distance
      ).call

      FileUtils.mkdir_p(REPORTS_DIR)
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      report_filename = "rag_evaluation_#{timestamp}.json"
      report_path = REPORTS_DIR.join(report_filename)
      File.write(report_path, JSON.pretty_generate(report.to_h))

      flash[:notice] = "Đánh giá Benchmark RAG thành công! Hit Rate@#{report.limit}: #{(report.hit_rate * 100).round(1)}%, MRR: #{report.mean_reciprocal_rank.round(3)}, Độ trễ trung bình: #{report.average_milliseconds.round(1)} ms."
      redirect_to admin_evaluations_path(report_id: report_filename)
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_evaluations_path, alert: "Không tìm thấy Workspace đã chọn."
    rescue ArgumentError, TypeError => e
      redirect_to admin_evaluations_path, alert: "Tham số không hợp lệ: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[Admin::EvaluationsController] Evaluation error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      redirect_to admin_evaluations_path, alert: "Đã xảy ra lỗi trong quá trình chạy đánh giá: #{e.message}"
    end

    def show
      clean_id = params[:id].to_s.sub(/(\.json)+\z/, "")
      report_item = load_reports_list.find { |r| r[:filename].sub(/\.json\z/, "") == clean_id }
      unless report_item
        return redirect_to admin_evaluations_path, alert: "Không tìm thấy tệp báo cáo."
      end

      filename = report_item[:filename]
      file_path = REPORTS_DIR.join(filename)
      file_path = Rails.root.join("tmp", filename) unless File.exist?(file_path)

      respond_to do |format|
        format.html { redirect_to admin_evaluations_path(report_id: filename) }
        format.json { send_data File.read(file_path), type: "application/json", disposition: "attachment", filename: filename }
        format.all { send_data File.read(file_path), type: "application/json", disposition: "attachment", filename: filename }
      end
    end

    private

    def valid_filename?(name)
      name.to_s.match?(FILENAME_PATTERN)
    end

    def find_report_path(filename)
      return nil unless valid_filename?(filename)

      storage_path = REPORTS_DIR.join(filename)
      return storage_path if File.exist?(storage_path)

      tmp_path = Rails.root.join("tmp", filename)
      return tmp_path if File.exist?(tmp_path)

      nil
    end

    def load_report_file(filename)
      path = find_report_path(filename)
      return nil unless path && File.exist?(path)

      data = JSON.parse(File.read(path))
      data["filename"] = filename
      data
    rescue JSON::ParserError
      nil
    end

    def load_reports_list
      FileUtils.mkdir_p(REPORTS_DIR)
      files = Dir.glob(REPORTS_DIR.join("rag_evaluation_*.json")).to_a +
              Dir.glob(Rails.root.join("tmp", "rag_evaluation_*.json")).to_a

      files.uniq { |f| File.basename(f) }.map do |file_path|
        basename = File.basename(file_path)
        begin
          content = JSON.parse(File.read(file_path))
          {
            filename: basename,
            created_at: File.mtime(file_path),
            workspace_id: content["workspace_id"],
            hit_rate: content["hit_rate"],
            mean_reciprocal_rank: content["mean_reciprocal_rank"],
            overall_accuracy: content["overall_accuracy"],
            case_count: content["case_count"],
            limit: content["limit"]
          }
        rescue StandardError
          {
            filename: basename,
            created_at: File.mtime(file_path),
            hit_rate: nil
          }
        end
      end.sort_by { |r| r[:created_at] }.reverse
    end
  end
end
