module Payments
  class SelectBestProcessor
    CHECK_INTERVAL = 5.seconds

    class << self
      def call
        refresh_health_if_needed
        choose_processor
      end

      private

      def refresh_health_if_needed
        @last_check ||= Time.at(0)
        return if Time.now - @last_check < CHECK_INTERVAL

        @last_result = {
          default: check_processor("default"),
          fallback: check_processor("fallback")
        }
        @last_check = Time.now
      end

      def check_processor(name)
        url = name == "default" ? "http://payment-processor-default:8080/payments/service-health" :
                                  "http://payment-processor-fallback:8080/payments/service-health"
        response = Faraday.get(url) do |req|
          req.options.timeout = 2
          req.options.open_timeout = 1
        end

        if response.status == 200
          data = JSON.parse(response.body)
          { healthy: !data["failing"], response_time: data["minResponseTime"] }
        else
          { healthy: false, response_time: 1000 }
        end
      rescue Faraday::Error => e
        { healthy: false, response_time: 1000, error: e.message }
      end

      def choose_processor
        default_health = @last_result[:default]
        fallback_health = @last_result[:fallback]

        if default_health[:healthy] && fallback_health[:healthy]
          default_health[:response_time] <= fallback_health[:response_time] ? "default" : "fallback"
        elsif default_health[:healthy]
          "default"
        elsif fallback_health[:healthy]
          "fallback"
        else
          "default"
        end
      end
    end
  end
end
