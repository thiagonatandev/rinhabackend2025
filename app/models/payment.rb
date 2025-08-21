class Payment < ApplicationRecord
  enum :status, { pending: 0, success: 1, failed: 2 }
  validates :correlation_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :processor, inclusion: { in: %w[default fallback] }
end
