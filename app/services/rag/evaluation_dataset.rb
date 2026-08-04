require "yaml"

module Rag
  class EvaluationDataset
    class Error < StandardError; end
    class InvalidDatasetError < Error; end

    MIN_RECOMMENDED_CASES = 15

    ExpectedSource = Data.define(
      :document_title,
      :page_number
    )

    Case = Data.define(
      :id,
      :question,
      :answerable,
      :expected_sources
    )

    def initialize(path:)
      @path = Pathname(path)
    end

    def call
      raw_cases = load_yaml.fetch("cases")
      validate_case_collection!(raw_cases)

      cases = raw_cases.map.with_index(1) do |attributes, index|
        build_case(attributes, index)
      end

      validate_unique_ids!(cases)
      validate_answerable_case!(cases)
      cases
    rescue Errno::ENOENT => error
      raise InvalidDatasetError,
        "Không tìm thấy evaluation dataset: #{error.message}"
    rescue Psych::Exception, KeyError, TypeError => error
      raise InvalidDatasetError,
        "Evaluation dataset không hợp lệ: #{error.message}"
    end

    private

    attr_reader :path

    def load_yaml
      YAML.safe_load_file(
        path,
        permitted_classes: [],
        permitted_symbols: [],
        aliases: false
      )
    end

    def validate_case_collection!(raw_cases)
      return if raw_cases.is_a?(Array) && raw_cases.any?

      raise InvalidDatasetError,
        "Evaluation dataset phải có ít nhất một case"
    end

    def build_case(attributes, index)
      unless attributes.is_a?(Hash)
        raise InvalidDatasetError,
          "Case thứ #{index} phải là một object"
      end

      id = attributes.fetch("id").to_s.squish
      question = SemanticSearch::Search.normalize_query!(
        attributes.fetch("question")
      )
      answerable = normalize_answerable(
        attributes.fetch("answerable", true),
        id.presence || index
      )
      expected_sources = build_expected_sources(
        attributes.fetch("expected_sources", []),
        id.presence || index,
        answerable: answerable
      )

      if id.blank?
        raise InvalidDatasetError,
          "Case thứ #{index} phải có id"
      end

      Case.new(
        id: id,
        question: question,
        answerable: answerable,
        expected_sources: expected_sources
      )
    rescue SemanticSearch::Search::InvalidQueryError => error
      raise InvalidDatasetError,
        "Câu hỏi của case #{id.presence || index} không hợp lệ: " \
          "#{error.message}"
    end

    def normalize_answerable(value, case_id)
      return value if value == true || value == false

      raise InvalidDatasetError,
        "answerable của case #{case_id} phải là true hoặc false"
    end

    def build_expected_sources(raw_sources, case_id, answerable:)
      unless raw_sources.is_a?(Array)
        raise InvalidDatasetError,
          "expected_sources của case #{case_id} phải là một array"
      end

      if answerable && raw_sources.empty?
        raise InvalidDatasetError,
          "Case #{case_id} có đáp án phải có expected_sources"
      end

      if !answerable && raw_sources.any?
        raise InvalidDatasetError,
          "Case #{case_id} không có đáp án phải để expected_sources rỗng"
      end

      raw_sources.map do |attributes|
        build_expected_source(attributes, case_id)
      end
    end

    def build_expected_source(attributes, case_id)
      unless attributes.is_a?(Hash)
        raise InvalidDatasetError,
          "Expected source của case #{case_id} phải là một object"
      end

      document_title = attributes.fetch("document_title").to_s.squish
      page_number = normalize_page_number(attributes["page_number"])

      if document_title.blank?
        raise InvalidDatasetError,
          "Expected source của case #{case_id} phải có document_title"
      end

      ExpectedSource.new(
        document_title: document_title,
        page_number: page_number
      )
    end

    def normalize_page_number(value)
      return nil if value.nil?

      page_number = Integer(value)
      return page_number if page_number.positive?

      raise ArgumentError
    rescue ArgumentError, TypeError
      raise InvalidDatasetError,
        "page_number phải là số nguyên dương hoặc null"
    end

    def validate_unique_ids!(cases)
      duplicate_id = cases.group_by(&:id).find do |_id, group|
        group.size > 1
      end&.first

      return unless duplicate_id

      raise InvalidDatasetError,
        "Case id bị trùng: #{duplicate_id}"
    end

    def validate_answerable_case!(cases)
      return if cases.any?(&:answerable)

      raise InvalidDatasetError,
        "Evaluation dataset phải có ít nhất một case có đáp án"
    end
  end
end
