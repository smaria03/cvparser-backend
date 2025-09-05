# frozen_string_literal: true

module Api
  class CvsController < ApplicationController
    def upload
      return render json: { error: 'No file uploaded' }, status: :bad_request unless params[:file]

      cv = CvUpload.new
      cv.file.attach(params[:file])

      if cv.save
        render json: {
          message: 'CV uploaded successfully',
          id: cv.id,
          filename: cv.file.filename.to_s,
          url: Rails.application.routes.url_helpers.rails_blob_url(cv.file, only_path: true)
        }, status: :ok
      else
        render json: { error: cv.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
