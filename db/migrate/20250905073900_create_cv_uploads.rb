# frozen_string_literal: true

class CreateCvUploads < ActiveRecord::Migration[6.1]
  def change
    create_table :cv_uploads do |t|
      t.string :source

      t.timestamps
    end
  end
end
