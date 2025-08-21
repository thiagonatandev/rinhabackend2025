# app/controllers/payments_controller.rb
class PaymentsController < ApplicationController
  def create
    return render_invalid_params if invalid_params?

    enqueue_payment_job

    head :accepted
  end

  def summary
    from = params[:from] ? Time.parse(params[:from]) : Time.at(0)
    to = params[:to] ? Time.parse(params[:to]) : Time.now

    default_payments = Payment.where(status: :success, processor: "default", created_at: from..to)
    fallback_payments = Payment.where(status: :success, processor: "fallback", created_at: from..to)

    render json: {
      default: {
        totalRequests: default_payments.count,
        totalAmount: default_payments.sum(:amount)
      },
      fallback: {
        totalRequests: fallback_payments.count,
        totalAmount: fallback_payments.sum(:amount)
      }
    }
  end

  private

  def invalid_params?
    params[:correlationId].blank? ||
    params[:amount].blank? ||
    params[:amount].to_f <= 0
  end

  def render_invalid_params
    render json: { error: "Invalid parameters" }, status: :unprocessable_entity
  end

  def enqueue_payment_job
    PaymentProcessorJob.perform_async(
      params[:correlationId],
      params[:amount].to_f
    )
  rescue Redis::CannotConnectError => e
    Rails.logger.error "Redis unavailable, falling back to synchronous processing: #{e.message}"
    process_synchronously
  end

  def process_synchronously
    result = Payments::ProcessPayment.new(
      correlation_id: params[:correlationId],
      amount: params[:amount].to_f
    ).call

    if result[:success]
      head :created
    else
      render json: { error: "Payment processors unavailable" }, status: :service_unavailable
    end
  end
end
