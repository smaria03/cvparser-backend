# frozen_string_literal: true

require 'pdf-reader'

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

    def destroy
      cv = CvUpload.find_by(id: params[:id])

      return render json: { error: 'CV not found' }, status: :not_found unless cv

      cv.file.purge if cv.file.attached?
      cv.destroy

      render json: { message: 'CV deleted successfully' }, status: :ok
    end

    def extract_text
      cv = CvUpload.find_by(id: params[:id])

      return render json: { error: 'CV not found' }, status: :not_found unless cv&.file&.attached?

      file_path = ActiveStorage::Blob.service.send(:path_for, cv.file.key)

      text = extract_pdf_text(file_path)

      render json: { text: text }, status: :ok
    end

    private

    def extract_pdf_text(path)
      reader = PDF::Reader.new(path)
      reader.pages.map(&:text).join("\n")
    end
  end
end
