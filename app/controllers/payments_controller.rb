class PaymentsController < ApplicationController
  def create
    result = Payments::ProcessPayment.new(
      correlation_id: params[:correlationId],
      amount: params[:amount]
    ).call

    if result[:success]
      Payment.create!(
        correlation_id: params[:correlationId],
        amount: params[:amount],
        processor: result[:processor],
        requested_at: Time.now.utc
      )
      head :created
    else
      render json: { error: "Payment processors unavailable" }, status: :service_unavailable
    end
  end
end
