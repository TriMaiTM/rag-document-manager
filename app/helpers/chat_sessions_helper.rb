module ChatSessionsHelper
  def chat_message_role_label(chat_message)
    chat_message.user? ? "Bạn" : "Codexys"
  end

  def chat_source_similarity_percentage(source)
    similarity = 1.0 - source.cosine_distance
    percentage = (similarity * 100).clamp(0, 100)

    number_to_percentage(percentage, precision: 1)
  end

  def render_chat_markdown(content)
    return "" if content.blank?

    text = content.to_s.strip

    # Split into lines to parse markdown bullet lists and bold text
    lines = text.split("\n")
    processed_lines = []
    in_list = false

    lines.each do |line|
      line_str = line.strip

      # Check if line is a bullet item starting with * or -
      if line_str.match?(/\A[\*\-]\s+/)
        # Strip leading bullet asterisk/hyphen
        item_text = line_str.sub(/\A[\*\-]\s+/, "")
        # Replace **bold** with <strong>
        item_text = item_text.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')

        unless in_list
          processed_lines << '<ul class="chat-bullet-list">'
          in_list = true
        end
        processed_lines << "<li class=\"chat-bullet-item\">#{item_text}</li>"
      else
        if in_list
          processed_lines << "</ul>"
          in_list = false
        end

        if line_str.present?
          # Replace **bold** with <strong> in regular paragraph lines
          line_text = line_str.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
          processed_lines << "<p>#{line_text}</p>"
        end
      end
    end

    processed_lines << "</ul>" if in_list

    sanitize(
      processed_lines.join("\n"),
      tags: %w[p br strong em ul li span code pre a],
      attributes: %w[href class target rel]
    )
  end
end
