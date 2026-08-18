module SemanticSearch
  class HybridSearch
    class Error < StandardError; end

    DEFAULT_LIMIT = 5
    RRF_K = 60

    def initialize(
      workspace:,
      query:,
      searcher: SemanticSearch::Search,
      generator: nil,
      limit: DEFAULT_LIMIT,
      rrf_k: RRF_K
    )
      @workspace = workspace
      @query = query
      @searcher = searcher
      @generator = generator
      @limit = limit
      @rrf_k = rrf_k
    end

    def call
      normalized_query = SemanticSearch::Search.normalize_query!(query)

      vector_result = vector_search(normalized_query)
      vector_chunks = vector_result.chunks

      keyword_chunks = keyword_search(normalized_query)

      fused_chunks = rrf_fuse(vector_chunks, keyword_chunks)

      SemanticSearch::Search::Result.new(
        query: normalized_query,
        chunks: fused_chunks.first(limit),
        sources: build_sources(fused_chunks.first(limit)),
        embedding_milliseconds: vector_result.embedding_milliseconds,
        vector_search_milliseconds: vector_result.vector_search_milliseconds
      )
    end

    private

    attr_reader :workspace, :query, :searcher, :generator, :limit, :rrf_k

    def vector_search(normalized_query)
      search_args = {
        workspace: workspace,
        query: normalized_query,
        limit: limit * 2
      }
      search_args[:generator] = generator if generator.present?

      searcher.new(**search_args).call
    rescue SemanticSearch::Search::Error => error
      Rails.logger.warn("Vector search failed in hybrid search: #{error.message}")
      SemanticSearch::Search::Result.new(
        query: normalized_query,
        chunks: [],
        sources: []
      )
    end

    def keyword_search(normalized_query)
      workspace_document_ids = workspace.documents.completed.pluck(:id)
      return [] if workspace_document_ids.empty?

      DocumentChunk
        .where(document_id: workspace_document_ids)
        .keyword_search(normalized_query)
        .preload(:document)
        .limit(limit * 2)
        .to_a
    rescue StandardError => error
      Rails.logger.warn("Keyword search failed in hybrid search: #{error.message}")
      []
    end

    def rrf_fuse(vector_chunks, keyword_chunks)
      scores = Hash.new(0.0)
      chunk_map = {}

      vector_chunks.each_with_index do |chunk, rank|
        cid = chunk_identifier(chunk)
        chunk_map[cid] = chunk
        scores[cid] += 1.0 / (rrf_k + rank + 1)
      end

      keyword_chunks.each_with_index do |chunk, rank|
        cid = chunk_identifier(chunk)
        chunk_map[cid] = chunk
        scores[cid] += 1.0 / (rrf_k + rank + 1)
      end

      sorted_ids = scores.keys.sort_by { |id| -scores[id] }
      sorted_ids.map { |id| chunk_map[id] }
    end

    def chunk_identifier(chunk)
      if chunk.respond_to?(:id) && chunk.id.present?
        chunk.id
      else
        chunk.object_id
      end
    end

    def build_sources(chunks)
      chunks.map.with_index(1) do |chunk, rank|
        doc = chunk.respond_to?(:document) ? chunk.document : nil
        doc_title = doc.respond_to?(:title) ? doc.title.to_s : ""

        {
          rank: rank,
          document_id: chunk.respond_to?(:document_id) ? chunk.document_id : nil,
          document_title: doc_title,
          page_number: chunk.respond_to?(:page_number) ? chunk.page_number : 1,
          cosine_distance: chunk.respond_to?(:neighbor_distance) && chunk.neighbor_distance.present? ? chunk.neighbor_distance : 0.2,
          content: chunk.respond_to?(:content) ? chunk.content.to_s : ""
        }
      end
    end
  end
end
