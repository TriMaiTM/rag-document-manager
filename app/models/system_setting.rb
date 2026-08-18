class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value.presence || default
  end

  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.update!(value: value.to_s)
  end
end
