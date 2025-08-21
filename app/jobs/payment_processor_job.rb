# app/jobs/payment_processor_job.rb
class PaymentProcessorJob
  include Sidekiq::Job
  sidekiq_options queue: "payments", retry: 5, backtrace: true

  sidekiq_options timeout: 10

  def perform(correlation_id, amount)
    return if duplicate?(correlation_id)

    result = process_payment(correlation_id, amount)

    handle_result(result, correlation_id)
  end

  private

  def duplicate?(correlation_id)
    key = "payment:#{correlation_id}"
    !Sidekiq.redis { |conn| conn.set(key, 1, ex: 1.hour, nx: true) }
  end

  def process_payment(correlation_id, amount)
    Payments::ProcessPayment.new(
      correlation_id: correlation_id,
      amount: amount
    ).call
  end

  def handle_result(result, correlation_id)
    if result[:success]
      Rails.logger.info "✅ Payment processed: #{correlation_id}"
    else
      Rails.logger.error "❌ Payment failed: #{correlation_id}, reason: #{result[:processor]}"
      raise "Payment processing failed: #{result[:processor]}" if should_retry?(result)
    end
  end

  def should_retry?(result)
    ![ "duplicate", "all_failed" ].include?(result[:processor])
  end
end
