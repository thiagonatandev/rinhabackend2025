# app/commands/payments/process_payment.rb
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
      return { success: false, processor: "duplicate" } if duplicate?

      selected_processor = SelectBestProcessor.call

      case selected_processor
      when "default"
        process_with_retry(DEFAULT_URL, "default")
      when "fallback"
        process_with_retry(FALLBACK_URL, "fallback")
      else
        process_with_retry(DEFAULT_URL, "default") ||
        process_with_retry(FALLBACK_URL, "fallback") ||
        failure
      end
    end

    private

    def process_with_retry(url, processor_name, retries = 2)
      retries.times do |attempt|
        result = try_processor(url, processor_name)
        return result if result && result[:success]
        
        sleep(0.1 * (attempt + 1))
      end
      
      nil
    end

    def duplicate?
      Payment.exists?(correlation_id: @correlation_id)
    end

    def process_with_default
      result = try_processor(DEFAULT_URL, "default")
      if result && result[:success]
        create_payment_record(result)
        return result
      end
      nil
    end

    def process_with_fallback
      result = try_processor(FALLBACK_URL, "fallback")
      if result && result[:success]
        create_payment_record(result)
        return result
      end
      nil
    end

    def try_processor(url, name)
      response = send_request(url)
      return { success: true, processor: name } if response.success?
      nil
    end

    def send_request(url)
      Faraday.post(url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.options.timeout = 5
        req.options.open_timeout = 2
        req.body = {
          correlationId: @correlation_id,
          amount: @amount,
          requestedAt: @requested_at
        }.to_json
      end
    rescue Faraday::Error => e
      Rails.logger.error "Payment processor error for #{url}: #{e.message}"
      OpenStruct.new(success?: false)
    end

    def create_payment_record(result)
      Payment.create!(
        correlation_id: @correlation_id,
        amount: @amount,
        processor: result[:processor],
        status: :success,
        requested_at: Time.now.utc
      )
    end

    def failure
      Rails.logger.error "All payment processors failed for: #{@correlation_id}"
      { success: false, processor: "all_failed" }
    end
  end
end
