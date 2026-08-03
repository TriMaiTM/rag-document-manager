require "test_helper"

class Chat::AskTest < ActiveSupport::TestCase
  class FakeAnswerer
    attr_reader :called

    def initialize(result)
      @result = result
      @called = false
    end

    def call
      @called = true
      @result
    end
  end

  setup do
    @workspace = workspaces(:one)
    @user = users(:one)
    @document = create_document
    @chunk = create_chunk
    @chunk.define_singleton_method(:neighbor_distance) { 0.2 }
  end

  teardown do
    @document.file.purge if @document.file.attached?
  end

  test "creates a session, message pair, and source snapshots" do
    answerer = FakeAnswerer.new(rag_result(chunks: [ @chunk ]))

    assert_difference("ChatSession.count", 1) do
      assert_difference("ChatMessage.count", 2) do
        assert_difference("ChatMessageSource.count", 1) do
          @result = Chat::Ask.new(
            workspace: @workspace,
            user: @user,
            question: "  Rails   security  ",
            answerer: answerer
          ).call
        end
      end
    end

    assert answerer.called
    assert_equal @workspace, @result.chat_session.workspace
    assert_equal @user, @result.chat_session.user
    assert_equal "Rails security", @result.chat_session.title
    assert_equal "Rails security", @result.user_message.content
    assert @result.user_message.user?

    assistant = @result.assistant_message
    assert assistant.assistant?
    assert_equal "Grounded answer [1]", assistant.content
    assert_equal "gemini-test", assistant.model
    assert_equal 120, assistant.total_tokens

    source = assistant.chat_message_sources.sole
    assert_equal @document, source.document
    assert_equal @chunk, source.document_chunk
    assert_equal @document.title, source.document_title
    assert_equal @chunk.content, source.content
    assert_equal 1, source.rank
    assert_in_delta 0.2, source.cosine_distance
  end

  test "appends a message pair to an existing session" do
    chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Existing chat"
    )

    assert_no_difference("ChatSession.count") do
      assert_difference("chat_session.chat_messages.count", 2) do
        Chat::Ask.new(
          workspace: @workspace,
          user: @user,
          question: "Follow-up",
          chat_session: chat_session,
          answerer: FakeAnswerer.new(rag_result(chunks: []))
        ).call
      end
    end
  end

  test "passes only the existing session recent history to RAG" do
    chat_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Contextual chat"
    )
    8.times do |index|
      chat_session.chat_messages.create!(
        role: index.even? ? :user : :assistant,
        content: "Message #{index}"
      )
    end
    other_session = ChatSession.create!(
      workspace: @workspace,
      user: @user,
      title: "Other chat"
    )
    other_session.chat_messages.create!(
      role: :user,
      content: "Must not leak"
    )

    answerer = FakeAnswerer.new(rag_result(chunks: []))
    answerer_arguments = nil
    answerer_factory = lambda do |**arguments|
      answerer_arguments = arguments
      answerer
    end

    Rag::AnswerQuestion.stub(:new, answerer_factory) do
      Chat::Ask.new(
        workspace: @workspace,
        user: @user,
        question: "Follow-up",
        chat_session: chat_session
      ).call
    end

    assert_equal @workspace, answerer_arguments[:workspace]
    assert_equal "Follow-up", answerer_arguments[:question]
    assert_equal (2..7).map { |index| "Message #{index}" },
      answerer_arguments[:history].map(&:content)
    assert_not_includes answerer_arguments[:history].map(&:content),
      "Must not leak"
  end

  test "rejects a session owned by another user" do
    chat_session = ChatSession.create!(
      workspace: @workspace,
      user: users(:two),
      title: "Private chat"
    )
    answerer = FakeAnswerer.new(rag_result(chunks: []))

    assert_raises(Chat::Ask::InvalidSessionError) do
      Chat::Ask.new(
        workspace: @workspace,
        user: @user,
        question: "Question",
        chat_session: chat_session,
        answerer: answerer
      ).call
    end

    assert_not answerer.called
  end

  test "keeps source snapshots after the document is deleted" do
    result = Chat::Ask.new(
      workspace: @workspace,
      user: @user,
      question: "Rails security",
      answerer: FakeAnswerer.new(rag_result(chunks: [ @chunk ]))
    ).call
    source = result.assistant_message.chat_message_sources.sole
    snapshot_content = source.content

    @document.destroy!
    source.reload

    assert_nil source.document
    assert_nil source.document_chunk
    assert_equal snapshot_content, source.content
    assert_equal "Rails Guide", source.document_title
  end

  private

  def create_document
    document = Document.new(
      workspace: @workspace,
      uploaded_by: @user,
      title: "Rails Guide",
      status: :completed
    )

    document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "chat-ask.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    document.save!
    document
  end

  def create_chunk
    @document.document_chunks.create!(
      content: "Rails uses authenticity tokens.",
      page_number: 3,
      position: 1,
      embedding: Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.1),
      embedding_provider: Ai::EmbeddingConfig::PROVIDER,
      embedding_model: Ai::EmbeddingConfig::MODEL,
      embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
    )
  end

  def rag_result(chunks:)
    Rag::AnswerQuestion::Result.new(
      query: "Rails security",
      answer: chunks.any? ? "Grounded answer [1]" :
        Rag::AnswerQuestion::NO_CONTEXT_ANSWER,
      chunks: chunks,
      model: chunks.any? ? "gemini-test" : nil,
      prompt_tokens: chunks.any? ? 100 : 0,
      candidate_tokens: chunks.any? ? 20 : 0,
      total_tokens: chunks.any? ? 120 : 0
    )
  end
end
