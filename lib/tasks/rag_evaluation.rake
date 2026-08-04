require "fileutils"
require "json"

namespace :rag do
  desc "Evaluate semantic retrieval and write a JSON report"
  task evaluate: :environment do
    workspace_id = ENV.fetch("WORKSPACE_ID")
    dataset_path = ENV.fetch(
      "DATASET",
      Rails.root.join("config/rag_evaluation.yml").to_s
    )
    limit = Integer(
      ENV.fetch("K", Rag::EvaluateRetrieval::DEFAULT_LIMIT.to_s)
    )

    workspace = Workspace.find(workspace_id)
    cases = Rag::EvaluationDataset.new(path: dataset_path).call

    puts "Workspace: #{workspace.name} (ID: #{workspace.id})"
    puts "Dataset: #{dataset_path}"
    puts "Cases: #{cases.size}; K: #{limit}"
    puts format(
      "Retrieval: model=%s; dimensions=%d; max cosine distance=%.3f",
      Ai::EmbeddingConfig::MODEL,
      Ai::EmbeddingConfig::DIMENSIONS,
      Rails.application.config.x.semantic_search.max_cosine_distance
    )
    puts format(
      "Chunking: max chars=%d; overlap chars=%d",
      Documents::ChunkText::DEFAULT_MAX_CHARS,
      Documents::ChunkText::DEFAULT_OVERLAP_CHARS
    )
    puts "Chi phí dự kiến: #{cases.size} embedding requests; 0 generation requests."

    unless ENV["CONFIRM_AI_COST"] == "1"
      abort "Đặt CONFIRM_AI_COST=1 để xác nhận và bắt đầu evaluation."
    end

    report = Rag::EvaluateRetrieval.new(
      workspace: workspace,
      cases: cases,
      limit: limit
    ).call

    report.results.each do |result|
      status = if result.error_class
        "ERROR #{result.error_class}"
      elsif !result.answerable
        result.correct ? "NO_ANSWER CORRECT" : "NO_ANSWER FALSE_POSITIVE"
      elsif result.hit
        "HIT rank=#{result.hit_rank}"
      else
        "MISS"
      end

      puts format(
        "[%s] %s - %.1f ms",
        status,
        result.id,
        result.duration_milliseconds
      )
    end

    puts format(
      "Hit Rate@%d: %.1f%% (%d/%d answerable cases)",
      report.limit,
      report.hit_rate * 100,
      report.hit_count,
      report.answerable_count
    )
    puts format(
      "MRR@%d: %.3f",
      report.limit,
      report.mean_reciprocal_rank
    )
    if report.unanswerable_count.positive?
      puts format(
        "No-answer accuracy: %.1f%% (%d/%d)",
        report.no_answer_accuracy * 100,
        report.no_answer_correct_count,
        report.unanswerable_count
      )
    end
    puts format(
      "Overall accuracy: %.1f%% (%d/%d); API errors: %.1f%% (%d/%d)",
      report.overall_accuracy * 100,
      report.correct_count,
      report.case_count,
      report.error_rate * 100,
      report.error_count,
      report.case_count
    )
    puts format(
      "Total retrieval latency: average %.1f ms; P95 %.1f ms",
      report.average_milliseconds,
      report.p95_milliseconds
    )
    puts format(
      "Query embedding latency: average %.1f ms; P95 %.1f ms",
      report.average_embedding_milliseconds,
      report.p95_embedding_milliseconds
    )
    puts format(
      "PostgreSQL vector search latency: average %.1f ms; P95 %.1f ms",
      report.average_vector_search_milliseconds,
      report.p95_vector_search_milliseconds
    )
    puts "Đạt mục tiêu Hit Rate: #{report.target_hit_rate_met}"
    puts "Đạt mục tiêu pgvector P95: #{report.target_p95_met}"

    unless report.recommended_case_count_met
      warn "Khuyến nghị dùng ít nhất " \
        "#{Rag::EvaluationDataset::MIN_RECOMMENDED_CASES} cases."
    end

    report_path = ENV.fetch(
      "REPORT",
      Rails.root.join(
        "tmp",
        "rag_evaluation_#{Time.current.strftime('%Y%m%d%H%M%S')}.json"
      ).to_s
    )
    FileUtils.mkdir_p(File.dirname(report_path))
    File.write(report_path, JSON.pretty_generate(report.to_h))

    puts "Report: #{report_path}"
  rescue KeyError => error
    abort "Thiếu biến môi trường: #{error.message}"
  rescue ActiveRecord::RecordNotFound,
    Rag::EvaluationDataset::Error,
    ArgumentError => error
    abort "Không thể chạy evaluation: #{error.message}"
  end
end
