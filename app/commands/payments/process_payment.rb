require "faraday"
require "ostruct"

module Payments
  class ProcessPayment
    DEFAULT_URL  = "http://payment-processor-default:8080/payments"
    FALLBACK_URL = "http://payment-processor-fallback:8080/payments"

    def initialize(correlation_id:, amount:)
      @correlation_id = correlation_id
      @amount = amount
      @requested_at = Time.now.utc.iso8601
    end

    def call
      try_processor(DEFAULT_URL, "default") ||
        try_processor(FALLBACK_URL, "fallback") ||
        failure
    end

    private

    def try_processor(url, name)
      response = send_request(url)

      return { success: true, processor: name } if response.success?

      nil
    end

    def send_request(url)
      Faraday.post(url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          correlationId: @correlation_id,
          amount: @amount,
          requestedAt: @requested_at
        }.to_json
      end
    rescue Faraday::Error
      OpenStruct.new(success?: false)
    end

    def failure
      { success: false }
    end
  end
end
