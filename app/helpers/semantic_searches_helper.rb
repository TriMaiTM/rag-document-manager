module SemanticSearchesHelper
  def semantic_similarity_percentage(chunk)
    similarity = 1.0 - chunk.neighbor_distance.to_f
    percentage = (similarity * 100).clamp(0, 100)

    number_to_percentage(percentage, precision: 1)
  end
end
