module ChatSessionsHelper
  def chat_message_role_label(chat_message)
    chat_message.user? ? "Bạn" : "Codexys"
  end

  def chat_source_similarity_percentage(source)
    similarity = 1.0 - source.cosine_distance
    percentage = (similarity * 100).clamp(0, 100)

    number_to_percentage(percentage, precision: 1)
  end
end
