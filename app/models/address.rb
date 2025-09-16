class Address < ApplicationRecord
  belongs_to :user

  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :birthday, presence: true
  validate :age_requirements
  validates :shipping_name, length: { maximum: 200 }, allow_blank: true
  validates :line_one, presence: true, length: { maximum: 255 }
  validates :line_two, length: { maximum: 255 }, allow_blank: true
  validates :city, presence: true, length: { maximum: 100 }
  validates :state, length: { maximum: 100 }
  validates :postcode, presence: true, length: { maximum: 20 }, format: { with: /\A[A-Za-z0-9\s\-]+\z/, message: "can only contain letters, numbers, spaces, and hyphens" }
  validates :country, presence: true,
            inclusion: {
              in: ISO3166::Country.codes,
              message: "must be a valid country code"
            }

  encrypts :first_name
  encrypts :last_name
  encrypts :shipping_name
  encrypts :line_one
  encrypts :line_two
  encrypts :city
  encrypts :state
  encrypts :postcode

  validates :user_id, uniqueness: true, presence: true

  def human_country
    return nil unless country.present?

    country_obj = ISO3166::Country[country]
    country_obj&.common_name
  end

  def owned_by?(user)
    self.user_id == user&.id
  end

  before_save :sanitize_attributes

  private

  def age_requirements
    return unless birthday.present?

    today = Date.current
    age = today.year - birthday.year
    age -= 1 if today < birthday + age.years

    if age > 18
      errors.add(:birthday, "You must be 18 years old or younger to participate")
    elsif age < 13
      errors.add(:birthday, "You must be at least 13 years old to participate")
    end
  end

  def sanitize_attributes
    self.first_name = first_name&.strip
    self.last_name = last_name&.strip
    self.shipping_name = shipping_name&.strip
    self.line_one = line_one&.strip
    self.line_two = line_two&.strip
    self.city = city&.strip
    self.state = state&.strip
    self.postcode = postcode&.strip&.upcase
    self.country = country&.strip
  end
end
