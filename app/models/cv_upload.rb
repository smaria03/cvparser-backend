# frozen_string_literal: true

class CvUpload < ApplicationRecord
  has_one_attached :file
end
