require "test_helper"

class Rag::ConversationContextTest < ActiveSupport::TestCase
  Message = Data.define(:role, :content)

  test "adds the latest user question to a short retrieval query" do
    context = Rag::ConversationContext.new(
      messages: [
        build_message(:user, "Devise hoạt động như thế nào?"),
        build_message(:assistant, "Devise xử lý xác thực."),
        build_message(:user, "Devise lưu mật khẩu bằng cách nào?"),
        build_message(:assistant, "Mật khẩu được hash.")
      ]
    )

    query = context.retrieval_query("nó đăng nhập thế nào?")

    assert_includes query, "nó đăng nhập thế nào?"
    assert_includes query, "Devise lưu mật khẩu bằng cách nào?"
    assert_not_includes query, "Devise hoạt động như thế nào?"
  end

  test "does not let history push a retrieval query over the limit" do
    question = "Q" * SemanticSearch::Search::MAX_QUERY_LENGTH
    context = Rag::ConversationContext.new(
      messages: [ build_message(:user, "Previous question") ]
    )

    assert_equal question, context.retrieval_query(question)
  end

  test "bounds transcript by message count and characters" do
    messages = 8.times.map do |index|
      build_message(
        index.even? ? :user : :assistant,
        "#{index}-#{'x' * 900}"
      )
    end
    context = Rag::ConversationContext.new(messages: messages)
    transcript = context.transcript

    assert_operator transcript.length,
      :<=,
      Rag::ConversationContext::MAX_CHARACTERS + 100
    assert_not_includes transcript, "Người dùng: 0-"
    assert_includes transcript, "Trợ lý: 7-"
  end

  private

  def build_message(role, content)
    Message.new(role: role.to_s, content: content)
  end
end
