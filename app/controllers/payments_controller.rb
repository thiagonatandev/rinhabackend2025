class PaymentsController < ApplicationController
  def create
    payment = Payment.new(payment_params)

    if payment.save
      render json: payment, status: :created
    else
      render json: { errors: payment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def payment_params
    params.permit(:amount).merge(correlation_id: params[:correlationId])
  end
end
