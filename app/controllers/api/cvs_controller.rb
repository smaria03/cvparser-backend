# frozen_string_literal: true

require 'pdf-reader'
require 'google_sheets_writer'
require Rails.root.join('lib/google_sheets_writer')

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

      begin
        result = PdfParserService.new(cv.file).extract_text

        name = result[:name]
        email = result[:email]
        applied_for = 'Full Stack Software Engineer'
        experience = result[:total_experience_years]

        begin
          GoogleSheetsWriter.new.append_row(
            name: name,
            email: email,
            applied_for: applied_for,
            experience: experience
          )
        rescue => sheet_error
          Rails.logger.error "[GoogleSheets] Failed to append row: #{sheet_error.message}"
        end

        render json: result, status: :ok
      rescue StandardError => e
        render json: { error: 'Failed to extract text', details: e.message },
               status: :unprocessable_entity
      end
    end
  end
end
