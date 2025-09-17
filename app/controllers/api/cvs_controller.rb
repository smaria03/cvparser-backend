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

      result = PdfParserService.new(cv.file).extract_text
      render json: result
    end

    def extract_sections
      cv = CvUpload.find_by(id: params[:id])
      return render json: { error: 'CV not found' }, status: :not_found unless cv&.file&.attached?

      result = PdfParserService.new(cv.file).extract_sections
      render json: result
    end

    def extract_summary
      cv = CvUpload.find_by(id: params[:id])
      return render json: { error: 'CV not found' }, status: :not_found unless cv&.file&.attached?

      result = PdfParserService.new(cv.file).extract_relevant_data
      render json: result
    end

    VALID_JOBS = [
      'Full Stack Software Engineer',
      'Internship',
      'QA'
    ].freeze

    def save_to_sheet
      summary = params.require(:summary).permit(
        :name,
        :email,
        :total_experience_years,
        :applied_for
      )

      applied_for = summary[:applied_for]
      unless VALID_JOBS.include?(applied_for)
        return render json: { error: 'Invalid job' }, status: :unprocessable_entity
      end

      begin
        write_to_google_sheets(summary.to_h.symbolize_keys)
        render json: { message: 'Saved to Google Sheets successfully' }, status: :ok
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end

    private

    def write_to_google_sheets(data)
      GoogleSheetsWriter.new.append_row(
        name: data[:name],
        email: data[:email],
        applied_for: data[:applied_for],
        experience: data[:total_experience_years]
      )
    rescue StandardError => e
      Rails.logger.error "[GoogleSheets] Failed to append row: #{e.message}"
    end
  end
end
