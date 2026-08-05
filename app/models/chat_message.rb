class ChatMessage < ApplicationRecord
  class InvalidStatusTransitionError < StandardError; end

  ERROR_CODE_MAX_LENGTH = 100

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[completed failed],
    "completed" => [],
    "failed" => %w[pending]
  }.freeze

  belongs_to :chat_session,
    touch: true,
    inverse_of: :chat_messages

  belongs_to :question_message,
    class_name: "ChatMessage",
    optional: true,
    inverse_of: :answer_message

  has_one :answer_message,
    class_name: "ChatMessage",
    foreign_key: :question_message_id,
    dependent: :destroy,
    inverse_of: :question_message

  has_many :chat_message_sources,
    -> { order(:rank) },
    dependent: :destroy,
    inverse_of: :chat_message

  enum :role, {
    user: "user",
    assistant: "assistant"
  }, validate: true

  enum :status, {
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }, validate: true

  validates :content, presence: true
  validates :error_code,
    length: { maximum: ERROR_CODE_MAX_LENGTH },
    allow_nil: true

  validates :prompt_tokens,
    :candidate_tokens,
    :total_tokens,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0
    }

  validate :user_message_has_no_generation_metadata
  validate :failure_metadata_is_consistent
  validate :user_message_is_completed
  validate :status_transition_is_allowed, on: :update
  validate :question_message_is_compatible

  def retryable?
    assistant? && failed? && question_message&.user?
  end

  def claim_retry!
    with_lock do
      unless retryable?
        raise InvalidStatusTransitionError,
          "Only failed assistant messages can be retried"
      end

      update!(status: :pending, error_code: nil)
    end
  end

  private

  def user_message_has_no_generation_metadata
    return unless user?

    metadata_present =
      model.present? ||
      prompt_tokens.positive? ||
      candidate_tokens.positive? ||
      total_tokens.positive?

    return unless metadata_present

    errors.add(
      :base,
      "Tin nhắn người dùng không được có metadata sinh nội dung"
    )
  end

  def failure_metadata_is_consistent
    if failed? && error_code.blank?
      errors.add(:error_code, "phải có khi tin nhắn thất bại")
    elsif !failed? && error_code.present?
      errors.add(
        :error_code,
        "phải để trống trừ khi tin nhắn thất bại"
      )
    end
  end

  def user_message_is_completed
    return unless user? && !completed?

    errors.add(:status, "của câu hỏi người dùng phải là completed")
  end

  def status_transition_is_allowed
    return unless will_save_change_to_status?

    previous_status, next_status = status_change_to_be_saved
    allowed_statuses = ALLOWED_STATUS_TRANSITIONS.fetch(
      previous_status,
      []
    )

    return if allowed_statuses.include?(next_status)

    errors.add(
      :status,
      "cannot transition from #{previous_status} to #{next_status}"
    )
  end

  def question_message_is_compatible
    return if question_message.nil?

    if user?
      errors.add(
        :question_message,
        "không được gắn vào tin nhắn người dùng"
      )
    elsif !question_message.user?
      errors.add(
        :question_message,
        "phải là tin nhắn của người dùng"
      )
    elsif question_message.chat_session_id != chat_session_id
      errors.add(
        :question_message,
        "phải thuộc cùng một phiên chat"
      )
    end
  end
end
