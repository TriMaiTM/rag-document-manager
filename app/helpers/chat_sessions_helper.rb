module ChatSessionsHelper
  def chat_message_role_label(chat_message)
    chat_message.user? ? "Bạn" : "Codexys"
  end

  def chat_source_similarity_percentage(source)
    similarity = 1.0 - source.cosine_distance
    percentage = (similarity * 100).clamp(0, 100)

    number_to_percentage(percentage, precision: 1)
  end

  def chat_source_focused_snippet(source, query = nil)
    return "" if source.blank? || source.content.blank?

    content = source.content.to_s.strip
    query_text = query.to_s.strip

    if query_text.present?
      keywords = query_text.scan(/\p{L}+|\p{N}+/).select { |w| w.length >= 2 }

      match_index = nil
      keywords.each do |kw|
        idx = content.downcase.index(kw.downcase)
        if idx
          match_index = idx
          break
        end
      end

      if match_index
        start_pos = [ 0, match_index - 80 ].max
        length = 480
        snippet = content[start_pos, length]

        snippet = "... #{snippet}" if start_pos > 0
        snippet = "#{snippet} ..." if (start_pos + length) < content.length

        return snippet
      end
    end

    truncate(content, length: 500)
  end

  def normalize_plain_numbers_in_math(text)
    return "" if text.blank?

    text.gsub(/\$(.*?)\$/) do |match|
      inner = $1.strip
      if inner.match?(/\A[\d\s\,\.\\\:]+(\\text\{[^\}]*\}|[a-zA-Z]{1,4})?\z/)
        inner.gsub(/\\text\{([^\}]*)\}/, "\\1").gsub(/\\,/, " ").gsub(/\\/, "")
      else
        match
      end
    end
  end

  def render_chat_markdown(content)
    return "" if content.blank?

    text = normalize_plain_numbers_in_math(content.to_s.strip)

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
