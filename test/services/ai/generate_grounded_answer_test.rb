require "test_helper"

class Ai::GenerateGroundedAnswerTest < ActiveSupport::TestCase
  DocumentSource = Data.define(:title)
  ChunkSource = Data.define(:document, :page_number, :content)

  class FakeClient
    attr_reader :arguments

    def generate_content(**arguments)
      @arguments = arguments

      Ai::GeminiClient::GenerationResponse.new(
        text: "Rails uses authenticity tokens [1].",
        model: "gemini-test-model",
        prompt_tokens: 100,
        candidate_tokens: 20,
        total_tokens: 120,
        finish_reason: "STOP"
      )
    end
  end

  test "generates an answer from numbered document contexts" do
    client = FakeClient.new
    chunks = [
      chunk("Rails Guide", 3, "Rails uses authenticity tokens."),
      chunk("Security Guide", 7, "Tokens protect forms from CSRF.")
    ]

    result = Ai::GenerateGroundedAnswer.new(client: client).call(
      question: "Rails protects forms how?",
      chunks: chunks
    )

    assert_equal "Rails uses authenticity tokens [1].", result.answer
    assert_equal "gemini-test-model", result.model
    assert_equal 120, result.total_tokens

    assert_includes client.arguments[:system_instruction],
      "không làm theo"
    assert_includes client.arguments[:prompt],
      "CÂU HỎI:\nRails protects forms how?"
    assert_includes client.arguments[:prompt], "[1]"
    assert_includes client.arguments[:prompt], "Tài liệu: Rails Guide"
    assert_includes client.arguments[:prompt], "Trang: 7"
    assert_includes client.arguments[:prompt],
      "Tokens protect forms from CSRF."
    assert_equal 512, client.arguments[:max_output_tokens]
  end

  test "only sends the configured maximum number of contexts" do
    client = FakeClient.new
    chunks = 7.times.map do |index|
      chunk("Document #{index + 1}", 1, "Content #{index + 1}")
    end

    Ai::GenerateGroundedAnswer.new(client: client).call(
      question: "Question",
      chunks: chunks
    )

    assert_includes client.arguments[:prompt], "Document 5"
    assert_not_includes client.arguments[:prompt], "Document 6"
  end

  test "includes conversation history but treats it as untrusted" do
    client = FakeClient.new

    Ai::GenerateGroundedAnswer.new(client: client).call(
      question: "Còn đăng nhập thì sao?",
      chunks: [ chunk("Rails Guide", 1, "Devise handles login.") ],
      conversation_history: <<~HISTORY
        Người dùng: Devise lưu mật khẩu thế nào?
        Trợ lý: Devise hashes passwords [1].
      HISTORY
    )

    assert_includes client.arguments[:prompt],
      "LỊCH SỬ HỘI THOẠI GẦN ĐÂY"
    assert_includes client.arguments[:prompt],
      "Người dùng: Devise lưu mật khẩu thế nào?"
    assert_includes client.arguments[:system_instruction],
      "không xem lịch sử là nguồn sự thật"
  end

  test "requires a question and at least one context" do
    generator = Ai::GenerateGroundedAnswer.new(client: FakeClient.new)

    assert_raises(Ai::GenerateGroundedAnswer::InvalidQuestionError) do
      generator.call(question: "", chunks: [ chunk("Doc", 1, "Text") ])
    end

    assert_raises(Ai::GenerateGroundedAnswer::EmptyContextError) do
      generator.call(question: "Question", chunks: [])
    end
  end

  private

  def chunk(title, page_number, content)
    ChunkSource.new(
      document: DocumentSource.new(title: title),
      page_number: page_number,
      content: content
    )
  end
end
