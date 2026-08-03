module Chat
  class Ask
    class Error < StandardError; end
    class InvalidSessionError < Error; end

    Result = Data.define(
      :chat_session,
      :user_message,
      :assistant_message,
      :rag_result
    )

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
      @answerer = answerer || Rag::AnswerQuestion.new(
        workspace: workspace,
        question: question
      )
    end

    def call
      validate_chat_session!
      rag_result = answerer.call

      persist(rag_result)
    end

    private

    attr_reader :workspace,
      :user,
      :question,
      :chat_session,
      :answerer

    def validate_chat_session!
      return unless chat_session
      return if chat_session.workspace_id == workspace.id &&
        chat_session.user_id == user.id

      raise InvalidSessionError,
        "Chat session does not belong to this user and workspace"
    end

    def persist(rag_result)
      ActiveRecord::Base.transaction do
        session = chat_session || create_session(rag_result.query)
        user_message = create_user_message(session, rag_result.query)
        assistant_message = create_assistant_message(session, rag_result)
        create_sources(assistant_message, rag_result.chunks)

        Result.new(
          chat_session: session,
          user_message: user_message,
          assistant_message: assistant_message,
          rag_result: rag_result
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
