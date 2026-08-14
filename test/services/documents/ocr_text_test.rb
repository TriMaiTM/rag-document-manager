require "test_helper"

module Documents
  class OcrTextTest < ActiveSupport::TestCase
    test "tesseract_available? returns boolean" do
      result = OcrText.tesseract_available?
      assert_includes [ true, false ], result
    end

    test "raises OcrNotAvailableError when tesseract is not available" do
      OcrText.stub :tesseract_available?, false do
        assert_raises OcrText::OcrNotAvailableError do
          OcrText.new(file_path: "nonexistent.png").call
        end
      end
    end
  end
end
