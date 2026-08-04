module Documents
  class Lifecycle
    class Error < StandardError; end
    class InvalidTransitionError < Error; end
    class StaleProcessingVersionError < Error; end

    STARTABLE_STATUSES = %w[pending processing failed].freeze

    def initialize(document:, clock: -> { Time.current })
      @document = document
      @clock = clock
    end

    def start_processing!
      document.with_lock do
        unless STARTABLE_STATUSES.include?(document.status)
          raise InvalidTransitionError,
            "Cannot start processing document with status #{document.status}"
        end

        started_at = document.processing? ?
          document.processing_started_at : now

        document.update!(
          status: :processing,
          processing_started_at: started_at || now,
          completed_at: nil,
          failed_at: nil,
          error_code: nil,
          error_message: nil
        )

        document.processing_version
      end
    end

    def complete!(expected_processing_version:)
      document.with_lock do
        validate_processing_version!(expected_processing_version)
        validate_status!("processing", action: "complete")

        yield document if block_given?
        completed_at = transition_time

        document.update!(
          status: :completed,
          completed_at: completed_at,
          failed_at: nil,
          error_code: nil,
          error_message: nil
        )
      end

      document
    end

    def fail!(error:, expected_processing_version:, attributes: {})
      document.with_lock do
        return false unless document.processing_version ==
          expected_processing_version

        return false unless document.processing?
        failed_at = transition_time

        document.update_columns(
          {
            status: "failed",
            completed_at: nil,
            failed_at: failed_at,
            error_code: error_code(error),
            error_message: safe_error_message(error),
            updated_at: failed_at
          }.merge(attributes)
        )
      end

      true
    end

    def retry!
      document.with_lock do
        validate_status!("failed", action: "retry")

        document.update!(
          status: :pending,
          processing_version: document.processing_version + 1,
          processing_started_at: nil,
          completed_at: nil,
          failed_at: nil,
          error_code: nil,
          error_message: nil
        )
      end

      document
    end

    private

    attr_reader :document, :clock

    def now
      clock.call
    end

    def transition_time
      [ now, document.processing_started_at ].compact.max
    end

    def validate_processing_version!(expected_version)
      return if document.processing_version == expected_version

      raise StaleProcessingVersionError,
        "Document started a newer processing version"
    end

    def validate_status!(expected_status, action:)
      return if document.status == expected_status

      raise InvalidTransitionError,
        "Cannot #{action} document with status #{document.status}"
    end

    def error_code(error)
      if error.respond_to?(:api_code) && error.api_code.present?
        return error.api_code.to_s.underscore
      end

      error.class.name.demodulize.underscore
    end

    def safe_error_message(error)
      error.message.to_s.truncate(1_000)
    end
  end
end
