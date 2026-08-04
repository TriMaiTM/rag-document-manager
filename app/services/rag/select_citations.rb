module Rag
  class SelectCitations
    CITATION_PATTERN = /\[(\d+)\]/

    Result = Data.define(:answer, :chunks)

    def initialize(answer:, chunks:)
      @answer = answer.to_s
      @chunks = Array(chunks)
    end

    def call
      rank_mapping = {}
      cited_chunks = []

      normalized_answer = answer.gsub(CITATION_PATTERN) do
        original_rank = ::Regexp.last_match(1).to_i
        chunk = chunks[original_rank - 1] if original_rank.positive?

        next "" unless chunk

        normalized_rank = rank_mapping[original_rank]
        unless normalized_rank
          normalized_rank = rank_mapping.size + 1
          rank_mapping[original_rank] = normalized_rank
          cited_chunks << chunk
        end

        "[#{normalized_rank}]"
      end

      Result.new(
        answer: normalized_answer,
        chunks: cited_chunks
      )
    end

    private

    attr_reader :answer, :chunks
  end
end
