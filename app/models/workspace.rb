class Workspace < ApplicationRecord
    validates :name, presence: true, length: { minimum: 2, maximum: 100 }
    validates :description, length: { maximum: 1_000 }, allow_blank: true
end
