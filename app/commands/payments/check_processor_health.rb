module Payments
  class CheckProcessorHealth
    DEFAULT_URL = "http://payment-processor-default:8080/admin/service-health"
    FALLBACK_URL = "http://payment-processor-fallback:8080/admin/service-health"

    def initialize(processor_name)
      @processor_name = processor_name
      @url = processor_name == "default" ? DEFAULT_URL : FALLBACK_URL
    end

    def call
      start_time = Time.now
      response = Faraday.get(@url) do |req|
        req.options.timeout = 1
        req.options.open_timeout = 1
      end

      response_time = (Time.now - start_time) * 1000

      {
        healthy: response.success?,
        response_time: response_time,
        status: response.status,
        processor: @processor_name
      }
    rescue Faraday::Error => e
      {
        healthy: false,
        response_time: 1000,
        error: e.message,
        processor: @processor_name
      }
    end
  end
end
