module Chat
  class Ask
    class Error < StandardError; end
    class InvalidSessionError < Error; end
    class WorkspaceAccessError < Error; end

    FAILURE_ANSWER =
      "Gemini chưa thể trả lời câu hỏi này. Bạn có thể thử lại sau."

    Result = Data.define(
      :chat_session,
      :user_message,
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
      question:,
      chat_session: nil,
      answerer: nil
    )
      @workspace = workspace
      @user = user
      @question = question
      @chat_session = chat_session
      @answerer = answerer
    end

    def call
      validate_workspace_access!
      validate_chat_session!

      normalized_question =
        SemanticSearch::Search.normalize_query!(question)
      history = recent_history
      session, user_message = persist_question(normalized_question)

      answer_question(
        session,
        user_message,
        normalized_question,
        history
      )
    end

    private

    attr_reader :workspace,
      :user,
      :question,
      :chat_session

    def answerer(normalized_question, history)
      @answerer ||= Rag::AnswerQuestion.new(
        workspace: workspace,
        question: normalized_question,
        history: history
      )
    end

    def recent_history
      return [] unless chat_session

      chat_session
        .chat_messages
        .where(status: :completed)
        .reorder(created_at: :desc, id: :desc)
        .limit(Rag::ConversationContext::MAX_MESSAGES)
        .to_a
        .reverse
    end

    def validate_workspace_access!
      return if workspace.membership_for(user).present?

      raise WorkspaceAccessError,
        "User does not belong to this workspace"
    end

    def validate_chat_session!
      return unless chat_session
      return if chat_session.workspace_id == workspace.id &&
        chat_session.user_id == user.id

      raise InvalidSessionError,
        "Chat session does not belong to this user and workspace"
    end

    def persist_question(normalized_question)
      ActiveRecord::Base.transaction do
        session = chat_session || create_session(normalized_question)
        user_message = create_user_message(session, normalized_question)

        [ session, user_message ]
      end
    end

    def answer_question(
      session,
      user_message,
      normalized_question,
      history
    )
      rag_result = answerer(normalized_question, history).call

      persist_answer(session, user_message, rag_result)
    rescue Rag::AnswerQuestion::GenerationError,
      Ai::GeminiClient::Error,
      Ai::GenerateQueryEmbedding::Error,
      Codexys::GeminiConfiguration::MissingApiKeyError => error
      persist_failure(session, user_message, error)
    end

    def persist_answer(session, user_message, rag_result)
      ActiveRecord::Base.transaction do
        assistant_message = create_assistant_message(session, rag_result)
        create_sources(assistant_message, rag_result.chunks)

        Result.new(
          chat_session: session,
          user_message: user_message,
          assistant_message: assistant_message,
          rag_result: rag_result,
          error: nil
        )
      end
    end

    def persist_failure(session, user_message, error)
      ActiveRecord::Base.transaction do
        assistant_message = session.chat_messages.create!(
          role: :assistant,
          status: :failed,
          error_code: error_code(error),
          content: FAILURE_ANSWER
        )

        Result.new(
          chat_session: session,
          user_message: user_message,
          assistant_message: assistant_message,
          rag_result: nil,
          error: error
        )
      end
    end

    def create_session(normalized_question)
      workspace.chat_sessions.create!(
        user: user,
        title: normalized_question.truncate(
          ChatSession::MAX_TITLE_LENGTH,
          separator: " "
        )
      )
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

    def create_user_message(session, normalized_question)
      session.chat_messages.create!(
        role: :user,
        content: normalized_question
      )
    end

    def create_assistant_message(session, rag_result)
      session.chat_messages.create!(
        role: :assistant,
        content: rag_result.answer,
        model: rag_result.model,
        prompt_tokens: rag_result.prompt_tokens,
        candidate_tokens: rag_result.candidate_tokens,
        total_tokens: rag_result.total_tokens
      )
    end

    def create_sources(assistant_message, chunks)
      chunks.each_with_index do |chunk, index|
        assistant_message.chat_message_sources.create!(
          document: chunk.document,
          document_chunk: chunk,
          rank: index + 1,
          document_title: chunk.document.title,
          page_number: chunk.page_number,
          content: chunk.content,
          cosine_distance: chunk.neighbor_distance
        )
      end
    end
  end
end
