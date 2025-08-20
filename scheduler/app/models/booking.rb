class Booking < ApplicationRecord
  belongs_to :customer
  belongs_to :service
  belongs_to :schedule_slot
end
