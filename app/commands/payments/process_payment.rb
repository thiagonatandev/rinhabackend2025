module Payments
  class ProcessPayment
    DEFAULT_URL = "http://payment-processor-default:8080/payments"
    FALLBACK_URL = "http://payment-processor-fallback:8080/payments"

    MAX_RETRIES = 3

    def initialize(correlation_id:, amount:)
      @correlation_id = correlation_id
      @amount = amount
      @requested_at = Time.now.utc.iso8601
    end

    def call
      return { success: false, processor: "duplicate" } if duplicate?

      processor = SelectBestProcessor.call
      result = try_with_retry(processor)

      unless result[:success] && processor == "default"
        # tenta fallback se default falhar
        result ||= try_with_retry("fallback") unless processor == "fallback"
      end

      result || failure
    end

    private

    def duplicate?
      key = "payment:#{@correlation_id}"
      !Sidekiq.redis { |conn| conn.set(key, 1, ex: 1.hour, nx: true) }
    end

    def try_with_retry(processor_name)
      url = processor_name == "default" ? DEFAULT_URL : FALLBACK_URL

      MAX_RETRIES.times do |attempt|
        result = try_processor(url, processor_name)
        return result if result[:success]

        sleep(0.2 * (2 ** attempt))
      end

      nil
    end

    def try_processor(url, name)
      response = Faraday.post(url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.options.open_timeout = 3
        req.options.timeout = 10
        req.body = {
          correlationId: @correlation_id,
          amount: @amount,
          requestedAt: @requested_at
        }.to_json
      end

      { success: response.status == 200, processor: name }
    rescue Faraday::Error => e
      Rails.logger.warn "Payment processor #{name} failed: #{e.message}"
      { success: false, processor: name }
    end

    def failure
      Rails.logger.error "All payment processors failed for #{@correlation_id}"
      { success: false, processor: "all_failed" }
    end
  end
end
