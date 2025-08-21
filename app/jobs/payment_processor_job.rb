class PaymentProcessorJob
  include Sidekiq::Job
  sidekiq_options queue: "payments", retry: 5, backtrace: true

  def perform(correlation_id, amount)
    result = Payments::ProcessPayment.new(correlation_id: correlation_id, amount: amount).call

    handle_result(result, correlation_id)
  end

  private

  def handle_result(result, correlation_id)
    if result[:success]
      Rails.logger.info "✅ Payment processed: #{correlation_id} via #{result[:processor]}"
      Payment.create!(
        correlation_id: correlation_id,
        amount: result[:amount] || 0,
        processor: result[:processor],
        status: "success"
      )
    else
      Rails.logger.error "❌ Payment failed: #{correlation_id}, reason: #{result[:processor]}"
      raise "Payment processing failed" if should_retry?(result)
    end
  end

  def should_retry?(result)
    ![ "duplicate", "all_failed" ].include?(result[:processor])
  end
end
