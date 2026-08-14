module Chat
  class RetryAnswer
    class Error < StandardError; end
    class InvalidMessageError < Error; end

    Result = Data.define(
      :assistant_message,
      :rag_result,
      :error
    ) do
      def failed?
        error.present?
      end
    end

    def initialize(
      workspace:,
      user:,
      assistant_message:,
      answerer: nil
    )
      @workspace = workspace
      @user = user
      @assistant_message = assistant_message
      @answerer = answerer
    end

    def call
      validate_access!

      question_message = assistant_message.question_message
      history = recent_history(question_message)

      assistant_message.claim_retry!

      rag_result = answerer(
        question_message.content,
        history
      ).call

      persist_success(rag_result)
    rescue Rag::AnswerQuestion::GenerationError,
      Ai::GeminiClient::Error,
      Ai::GenerateQueryEmbedding::Error,
      Codexys::GeminiConfiguration::MissingApiKeyError => error
      persist_failure(error)
    end

    private

    attr_reader :workspace,
      :user,
      :assistant_message

    def answerer(question, history)
      @answerer || Rag::AnswerQuestion.new(
        workspace: workspace,
        question: question,
        history: history
      )
    end

    def validate_access!
      session = assistant_message.chat_session

      valid_access =
        workspace.membership_for(user).present? &&
        session.workspace_id == workspace.id &&
        session.user_id == user.id &&
        assistant_message.retryable?

      return if valid_access

      raise InvalidMessageError,
        "Message cannot be retried by this user"
    end

    def recent_history(question_message)
      question_message
        .chat_session
        .chat_messages
        .where(status: :completed)
        .where("id < ?", question_message.id)
        .reorder(id: :desc)
        .limit(Rag::ConversationContext::MAX_MESSAGES)
        .to_a
        .reverse
    end

    def persist_success(rag_result)
      assistant_message.with_lock do
        ensure_pending!

        assistant_message.chat_message_sources.destroy_all

        assistant_message.update!(
          status: :completed,
          content: rag_result.answer,
          error_code: nil,
          model: rag_result.model,
          prompt_tokens: rag_result.prompt_tokens,
          candidate_tokens: rag_result.candidate_tokens,
          total_tokens: rag_result.total_tokens
        )

        create_sources(rag_result.chunks)
      end

      Result.new(
        assistant_message: assistant_message,
        rag_result: rag_result,
        error: nil
      )
    end

    def persist_failure(error)
      assistant_message.with_lock do
        ensure_pending!

        assistant_message.chat_message_sources.destroy_all

        assistant_message.update!(
          status: :failed,
          content: Chat::Ask::FAILURE_ANSWER,
          error_code: error_code(error),
          model: nil,
          prompt_tokens: 0,
          candidate_tokens: 0,
          total_tokens: 0
        )
      end

      Result.new(
        assistant_message: assistant_message,
        rag_result: nil,
        error: error
      )
    end

    def ensure_pending!
      return if assistant_message.pending?

      raise ChatMessage::InvalidStatusTransitionError,
        "Retry is no longer pending"
    end

    def create_sources(chunks)
      chunks.each_with_index do |chunk, index|
        distance = if chunk.respond_to?(:neighbor_distance) && chunk.neighbor_distance.present?
          chunk.neighbor_distance
        else
          0.2
        end

        assistant_message.chat_message_sources.create!(
          document: chunk.document,
          document_chunk: chunk,
          rank: index + 1,
          document_title: chunk.document.title,
          page_number: chunk.page_number,
          chunk_position: chunk.position,
          content: chunk.content,
          cosine_distance: distance
        )
      end
    end

    def error_code(error)
      original_error = if error.respond_to?(:original_error)
        error.original_error
      else
        error
      end

      code = if original_error.respond_to?(:api_code) &&
        original_error.api_code.present?
        original_error.api_code
      else
        original_error.class.name.demodulize.underscore
      end

      code.to_s.truncate(
        ChatMessage::ERROR_CODE_MAX_LENGTH,
        omission: ""
      )
    end
  end
end
