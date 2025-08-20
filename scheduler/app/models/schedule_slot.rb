class ScheduleSlot < ApplicationRecord
  belongs_to :service
  belongs_to :provider
  belongs_to :location
end
