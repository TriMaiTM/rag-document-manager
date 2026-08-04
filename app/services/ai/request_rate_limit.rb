module Ai
  module RequestRateLimit
    BURST_LIMIT = 5
    BURST_WINDOW = 1.minute
    HOURLY_LIMIT = 20
    HOURLY_WINDOW = 1.hour
    SCOPE = :gemini_user_requests

    class << self
      def store
        @store ||= if Rails.env.test?
          ActiveSupport::Cache::MemoryStore.new
        else
          Rails.cache
        end
      end
    end
  end
end
