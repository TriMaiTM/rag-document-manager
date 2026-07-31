module Documents
  class ChunkText
    DEFAULT_MAX_CHARS = 1_200
    DEFAULT_OVERLAP_CHARS = 200

    Chunk = Data.define(
      :position,
      :page_number,
      :content
    )

    def initialize(
      pages:,
      max_chars: DEFAULT_MAX_CHARS,
      overlap_chars: DEFAULT_OVERLAP_CHARS
    )
      @pages = pages
      @max_chars = max_chars
      @overlap_chars = overlap_chars
    end

    def call
      validate_options!

      position = 0

      pages.each_with_object([]) do |page, chunks|
        chunks_for(page).each do |content|
          position += 1

          chunks << Chunk.new(
            position: position,
            page_number: page.number,
            content: content
          )
        end
      end
    end

    private

    attr_reader :pages, :max_chars, :overlap_chars

    def validate_options!
      unless max_chars.is_a?(Integer) && max_chars.positive?
        raise ArgumentError,
          "max_chars phải là số nguyên lớn hơn 0"
      end

      valid_overlap =
        overlap_chars.is_a?(Integer) &&
        overlap_chars >= 0 &&
        overlap_chars < max_chars

      return if valid_overlap

      raise ArgumentError,
        "overlap_chars phải từ 0 đến max_chars - 1"
    end

    def chunks_for(page)
      return [] if page.text.blank?

      units = split_into_units(page.text)
      build_chunks(units)
    end

    def split_into_units(text)
      paragraphs = text
        .split(/\n{2,}/)
        .map(&:strip)
        .reject(&:blank?)

      paragraphs.flat_map do |paragraph|
        split_paragraph(paragraph)
      end
    end

    def split_paragraph(paragraph)
      return [ paragraph ] if paragraph.length <= max_chars

      sentences = paragraph
        .split(/(?<=[.!?])\s+/)
        .map(&:strip)
        .reject(&:blank?)

      parts = sentences.flat_map do |sentence|
        if sentence.length <= max_chars
          sentence
        else
          split_by_words(sentence)
        end
      end

      pack_parts(parts, separator: " ")
    end

    def split_by_words(text)
      words = text
        .split(/\s+/)
        .flat_map { |word| split_oversized_word(word) }

      pack_parts(words, separator: " ")
    end

    def split_oversized_word(word)
      return [ word ] if word.length <= max_chars

      word
        .chars
        .each_slice(max_chars)
        .map(&:join)
    end

    def pack_parts(parts, separator:)
      result = []
      current = ""

      parts.each do |part|
        candidate = join_parts(
          current,
          part,
          separator: separator
        )

        if candidate.length <= max_chars
          current = candidate
        else
          result << current unless current.empty?
          current = part
        end
      end

      result << current unless current.empty?
      result
    end

    def build_chunks(units)
      chunks = []
      current = ""

      units.each do |unit|
        candidate = join_parts(
          current,
          unit,
          separator: "\n\n"
        )

        if candidate.length <= max_chars
          current = candidate
          next
        end

        chunks << current unless current.empty?

        overlap = overlap_for(
          current,
          next_content: unit
        )

        current = join_parts(
          overlap,
          unit,
          separator: "\n\n"
        )
      end

      chunks << current unless current.empty?
      chunks
    end

    def overlap_for(previous_content, next_content:)
      separator_size = 2
      available_size =
        max_chars -
        next_content.length -
        separator_size

      return "" unless available_size.positive?

      requested_size = [
        overlap_chars,
        available_size
      ].min

      tail_without_partial_word(
        previous_content,
        requested_size
      )
    end

    def tail_without_partial_word(text, size)
      return "" unless size.positive?
      return text.strip if text.length <= size

      start_index = text.length - size
      return text.last(size).strip if text[start_index - 1].match?(/\s/)

      tail = text.last(size)

      return tail.strip if tail.match?(/\A\s/)

      first_space = tail.index(/\s/)
      return "" unless first_space

      tail[(first_space + 1)..].strip
    end

    def join_parts(left, right, separator:)
      return right if left.empty?

      "#{left}#{separator}#{right}"
    end
  end
end
