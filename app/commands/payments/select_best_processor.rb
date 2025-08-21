module Payments
  class SelectBestProcessor
    CHECK_INTERVAL = 5.seconds

    class << self
      def call
        @last_check ||= {}
        @last_result ||= {}

        if @last_check[:time].nil? || Time.now - @last_check[:time] > CHECK_INTERVAL
          refresh_health_data
        end

        choose_processor
      end

      private

      def refresh_health_data
        default_check = CheckProcessorHealth.new("default").call
        fallback_check = CheckProcessorHealth.new("fallback").call

        @last_result = {
          default: default_check,
          fallback: fallback_check
        }

        @last_check = { time: Time.now }
      end

      def choose_processor
        default_health = @last_result[:default]
        fallback_health = @last_result[:fallback]

        if default_health[:healthy] && !fallback_health[:healthy]
          "default"
        elsif fallback_health[:healthy] && !default_health[:healthy]
          "fallback"
        elsif default_health[:healthy] && fallback_health[:healthy]
          default_health[:response_time] <= fallback_health[:response_time] ? "default" : "fallback"
        else
          "default"
        end
      end
    end
  end
end
