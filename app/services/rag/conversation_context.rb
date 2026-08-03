module Rag
  class ConversationContext
    Entry = Data.define(:role, :content)

    MAX_MESSAGES = 6
    MAX_CHARACTERS = 4_000

    def initialize(messages:)
      @messages = messages
    end

    def retrieval_query(question)
      previous_question = entries.reverse.find do |entry|
        entry.role == "user"
      end&.content

      return question if previous_question.blank?

      contextual_query = <<~QUERY.squish
        #{question}
        Ngữ cảnh từ câu hỏi trước: #{previous_question}
      QUERY

      if contextual_query.length <= SemanticSearch::Search::MAX_QUERY_LENGTH
        contextual_query
      else
        question
      end
    end

    def transcript
      entries.map do |entry|
        speaker = entry.role == "user" ? "Người dùng" : "Trợ lý"
        "#{speaker}: #{entry.content}"
      end.join("\n")
    end

    private

    attr_reader :messages

    def entries
      @entries ||= build_entries
    end

    def build_entries
      selected = []
      characters = 0

      Array(messages).reverse_each do |message|
        break if selected.size >= MAX_MESSAGES

        content = message.content.to_s.squish
        next if content.blank?

        remaining = MAX_CHARACTERS - characters
        break unless remaining.positive?

        content = content.truncate(remaining, omission: "")
        selected << Entry.new(
          role: message.role.to_s,
          content: content
        )
        characters += content.length
      end

      selected.reverse
    end
  end
end
