# frozen_string_literal: true

require 'pdf-reader'
require 'google_sheets_writer'
require 'googleauth/stores/file_token_store'
require Rails.root.join('lib/google_sheets_writer')

module Api
  class CvsController < ApplicationController
    include GoogleDriveHelpers

    CANDIDATES_FOLDER_ID = '1bPm0qSGjl_esvh_YPkVeddb_3RuDoF6o'

    def upload
      return render json: { error: 'No file uploaded' }, status: :bad_request unless params[:file]

      file = params[:file]
      filename = file.original_filename
      io = file.tempfile

      drive_service = build_drive_service

      summary = PdfParserService.new(io).extract_relevant_data
      candidate_name = summary[:name].presence || 'Unnamed Candidate'
      candidate_folder_id = find_or_create_subfolder(drive_service, CANDIDATES_FOLDER_ID,
                                                     candidate_name)

      metadata = {
        name: 'CV.pdf',
        mime_type: 'application/pdf',
        parents: [candidate_folder_id]
      }

      uploaded_file = drive_service.create_file(
        metadata,
        fields: 'id, webViewLink',
        upload_source: io,
        content_type: 'application/pdf'
      )

      folder_link = "https://drive.google.com/drive/folders/#{candidate_folder_id}"
      cv = CvUpload.create!(
        google_drive_link: folder_link,
        google_drive_file_id: uploaded_file.id
      )

      render json: {
        message: 'CV uploaded to Google Drive successfully',
        id: cv.id,
        filename: filename,
        candidate_folder: candidate_name,
        drive_url: folder_link,
        file_id: uploaded_file.id
      }, status: :ok
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end

    def destroy
      cv = CvUpload.find_by(id: params[:id])

      return render json: { error: 'CV not found' }, status: :not_found unless cv

      cv.destroy

      render json: { message: 'CV deleted successfully' }, status: :ok
    end

    def extract_text
      parse_cv_file(params[:id]) do |tempfile|
        PdfParserService.new(tempfile).extract_text
      end
    end

    def extract_sections
      parse_cv_file(params[:id]) do |tempfile|
        PdfParserService.new(tempfile).extract_sections
      end
    end

    def extract_summary
      parse_cv_file(params[:id]) do |tempfile|
        PdfParserService.new(tempfile).extract_relevant_data
      end
    end

    def save_to_sheet
      summary = params.require(:summary).permit(
        :name,
        :email,
        :total_experience_years,
        :applied_for,
        :drive_url,
        :sheet,
        :skills,
        experiences: %i[job_details period]
      )

      sheet = summary[:sheet]
      available_sheets = GoogleSheetsWriter.new.list_sheets
      unless available_sheets.include?(sheet)
        return render json: { error: "Sheet #{sheet} does not exist." }, status: :unprocessable_entity
      end

      if summary[:applied_for].blank?
        return render json: { error: 'Applied For field cannot be empty' },
                      status: :unprocessable_entity
      end

      begin
        write_to_google_sheets(summary.to_h.symbolize_keys.merge(sheet: sheet))
        render json: { message: "#{summary[:name]} was successfully added to “#{sheet}” sheet." },
               status: :ok
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end

    def list_sheets
      sheets = GoogleSheetsWriter.new.list_sheets
      render json: { sheets: sheets }, status: :ok
    rescue StandardError => e
      Rails.logger.error "[GoogleSheets] Failed to list sheets: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def recalculate_experience
      experiences = params[:experiences]
      unless experiences
        return render json: { error: 'No experiences provided' },
                      status: :bad_request
      end

      result = PdfParserService.new(nil).recalculate_experience(experiences)
      render json: { total_experience_years: result }
    end

    private

    def write_to_google_sheets(data)
      normalized_experiences = data[:experiences]&.map(&:symbolize_keys)
      GoogleSheetsWriter.new.append_row(
        name: data[:name],
        email: data[:email],
        applied_for: data[:applied_for],
        drive_url: data[:drive_url],
        experience: data[:total_experience_years],
        sheet: data[:sheet],
        skills: data[:skills],
        experiences: normalized_experiences
      )
    rescue StandardError => e
      Rails.logger.error "[GoogleSheets] Failed to append row: #{e.message}"
      raise e
    end
  end
end
