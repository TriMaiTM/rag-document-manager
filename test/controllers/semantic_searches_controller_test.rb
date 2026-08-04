require "test_helper"

class SemanticSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Ai::RequestRateLimit.store.clear

    @workspace = workspaces(:one)
    sign_in_as users(:one)
  end

  teardown do
    @document&.file&.purge if @document&.file&.attached?
  end

  test "requires authentication" do
    sign_out

    get workspace_semantic_search_url(@workspace)

    assert_redirected_to new_user_session_url
  end

  test "renders the search form without calling Gemini" do
    get workspace_semantic_search_url(@workspace)

    assert_response :success
    assert_select "h1", "Tìm kiếm ngữ nghĩa"
    assert_select "form[method='get']"
    assert_select "input[name='query']"
    assert_select "h2", text: "Câu trả lời", count: 0
  end

  test "renders workspace-scoped semantic results" do
    chunk = create_embedded_chunk
    chunk.define_singleton_method(:neighbor_distance) { 0.125 }

    service = Object.new
    service.define_singleton_method(:call) do
      Rag::AnswerQuestion::Result.new(
        query: "Rails security",
        answer: "Rails protects forms with authenticity tokens [1].",
        chunks: [ chunk ],
        model: "gemini-test-model",
        prompt_tokens: 100,
        candidate_tokens: 20,
        total_tokens: 120
      )
    end

    factory = ->(**_arguments) { service }

    Rag::AnswerQuestion.stub(:new, factory) do
      get workspace_semantic_search_url(@workspace),
        params: { query: "  Rails security  " }
    end

    assert_response :success
    assert_select "h2", "Câu trả lời"
    assert_select "h2", "Nguồn tham khảo"
    assert_select "input[name='query'][value='Rails security']"
    assert_select "p", /authenticity tokens \[1\]/
    assert_select "article", 1
    assert_select "a", @document.title
    assert_select "p", text: /Trang 1/
    assert_select "p", text: /87,5%|87\.5%/
    assert_select "p", text: chunk.content
  end

  test "shows a validation error for a blank query" do
    get workspace_semantic_search_url(@workspace),
      params: { query: " " }

    assert_response :success
    assert_select "[role='alert']", /ít nhất 2 ký tự/
  end

  test "does not present retrieved candidates as citations when generation times out" do
    chunk = create_embedded_chunk
    chunk.define_singleton_method(:neighbor_distance) { 0.2 }
    network_error = Ai::GeminiClient::NetworkError.new(
      Net::ReadTimeout.new("execution expired")
    )
    generation_error = Rag::AnswerQuestion::GenerationError.new(
      query: "Rails security",
      chunks: [ chunk ],
      original_error: network_error
    )
    service = Object.new
    service.define_singleton_method(:call) { raise generation_error }
    factory = ->(**_arguments) { service }

    Rag::AnswerQuestion.stub(:new, factory) do
      get workspace_semantic_search_url(@workspace),
        params: { query: "Rails security" }
    end

    assert_response :success
    assert_select "[role='alert']", /Gemini chưa thể tạo câu trả lời/
    assert_select "h2", text: "Nguồn tham khảo", count: 0
    assert_select "a", text: @document.title, count: 0
  end

  test "member can search" do
    sign_out
    sign_in_as users(:two)

    get workspace_semantic_search_url(@workspace)

    assert_response :success
  end

  test "outsider receives not found" do
    sign_out
    sign_in_as users(:four)

    get workspace_semantic_search_url(@workspace)

    assert_response :not_found
  end

  private

  def create_embedded_chunk
    @document = Document.new(
      workspace: @workspace,
      uploaded_by: users(:one),
      title: "Rails Security",
      status: :completed
    )

    @document.file.attach(
      io: file_fixture("sample.pdf").open,
      filename: "rails-security.pdf",
      content_type: Document::PDF_CONTENT_TYPE
    )
    @document.save!

    @document.document_chunks.create!(
      content: "Rails protects forms with authenticity tokens.",
      page_number: 1,
      position: 1,
      embedding: Array.new(Ai::EmbeddingConfig::DIMENSIONS, 0.1),
      embedding_provider: Ai::EmbeddingConfig::PROVIDER,
      embedding_model: Ai::EmbeddingConfig::MODEL,
      embedding_dimensions: Ai::EmbeddingConfig::DIMENSIONS
    )
  end
end
