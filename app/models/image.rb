class Image < ApplicationRecord
  # Status constants
  STATUSES = %w[uploaded processing completed failed].freeze

  # Validations
  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :share_token, presence: true, uniqueness: true

  # Active Storage associations
  has_one_attached :original_image
  has_one_attached :pixelated_image
  has_one_attached :paint_by_number_image

  # Callbacks
  before_validation :generate_share_token, on: :create
  before_validation :set_default_status, on: :create

  # Scopes
  scope :completed, -> { where(status: "completed") }

  def self.find_by_share_token!(token)
    find_by!(share_token: token)
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  private

  def generate_share_token
    self.share_token = SecureRandom.urlsafe_base64(16) if share_token.blank?
  end

  def set_default_status
    self.status = "uploaded" if status.blank?
  end
end
