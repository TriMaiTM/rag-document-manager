require "test_helper"

class Documents::ChunkTextTest < ActiveSupport::TestCase
  test "creates ordered chunks without crossing pages" do
    pages = [
      page(
        1,
        "Rails follows conventions.\n\n" \
          "Active Record manages persistence."
      ),
      page(2, ""),
      page(3, "Background jobs run asynchronously.")
    ]

    chunks = chunk(
      pages,
      max_chars: 100,
      overlap_chars: 10
    )

    assert_equal 2, chunks.size
    assert_equal [ 1, 2 ], chunks.map(&:position)
    assert_equal [ 1, 3 ], chunks.map(&:page_number)

    assert_includes chunks.first.content,
      "Rails follows conventions."

    assert_includes chunks.last.content,
      "Background jobs run asynchronously."
  end

  test "splits long paragraphs at sentence boundaries" do
    original_text = [
      "Rails applications organize code around conventions.",
      "Active Record handles persistence for domain models.",
      "Background jobs process expensive work asynchronously."
    ].join(" ")

    chunks = chunk(
      [ page(1, original_text) ],
      max_chars: 70,
      overlap_chars: 0
    )

    assert_operator chunks.size, :>, 1

    assert chunks.all? { |item|
      item.content.length <= 70
    }

    reconstructed_text =
      chunks.map(&:content).join(" ")

    assert_equal original_text, reconstructed_text
  end

  test "splits an oversized sentence without cutting words" do
    original_text =
      Array.new(20, "codexys").join(" ")

    chunks = chunk(
      [ page(1, original_text) ],
      max_chars: 35,
      overlap_chars: 0
    )

    assert_operator chunks.size, :>, 1

    assert chunks.all? { |item|
      item.content.length <= 35
    }

    assert_equal(
      original_text,
      chunks.map(&:content).join(" ")
    )
  end

  test "adds overlap from the previous chunk" do
    text =
      "alpha beta gamma delta.\n\n" \
      "one two three four five six."

    chunks = chunk(
      [ page(4, text) ],
      max_chars: 36,
      overlap_chars: 10
    )

    assert_equal 2, chunks.size
    assert_equal 4, chunks.first.page_number
    assert_equal 4, chunks.second.page_number

    assert_equal(
      "alpha beta gamma delta.",
      chunks.first.content
    )

    assert_equal(
      "delta.\n\none two three four five six.",
      chunks.second.content
    )

    assert chunks.all? { |item|
      item.content.length <= 36
    }
  end

  test "hard splits a single word longer than max chars" do
    chunks = chunk(
      [ page(1, "abcdefghijklmnop") ],
      max_chars: 5,
      overlap_chars: 0
    )

    assert_equal(
      [ "abcde", "fghij", "klmno", "p" ],
      chunks.map(&:content)
    )
  end

  test "rejects invalid max chars" do
    assert_raises(ArgumentError) do
      chunk(
        [ page(1, "Content") ],
        max_chars: 0,
        overlap_chars: 0
      )
    end
  end

  test "rejects overlap equal to max chars" do
    assert_raises(ArgumentError) do
      chunk(
        [ page(1, "Content") ],
        max_chars: 20,
        overlap_chars: 20
      )
    end
  end

  private

  def page(number, text)
    Documents::ExtractText::Page.new(
      number: number,
      text: text
    )
  end

  def chunk(
    pages,
    max_chars:,
    overlap_chars:
  )
    Documents::ChunkText.new(
      pages: pages,
      max_chars: max_chars,
      overlap_chars: overlap_chars
    ).call
  end
end
