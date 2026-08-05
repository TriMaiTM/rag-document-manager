module SemanticSearch
  class SourceExcerpt < Data.define(
    :rank,
    :chunk_id,
    :document_id,
    :document_title,
    :page_number,
    :content,
    :cosine_distance
  )
    MAX_CONTENT_LENGTH = 500

    def self.from_chunk(chunk, rank:)
      new(
        rank: rank,
        chunk_id: chunk.id,
        document_id: chunk.document.id,
        document_title: chunk.document.title,
        page_number: chunk.page_number,
        content: excerpt(chunk.content),
        cosine_distance: chunk.neighbor_distance.to_f
      )
    end

    def similarity
      (1.0 - cosine_distance).clamp(0.0, 1.0)
    end

    def self.excerpt(content)
      content
        .to_s
        .squish
        .truncate(
          MAX_CONTENT_LENGTH,
          omission: "…"
        )
    end

    private_class_method :excerpt
  end
end
