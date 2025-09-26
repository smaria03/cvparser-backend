require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetsWriter
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
  SPREADSHEET_ID = '1UihqJI_GpNIKvwg8gDz7pJ3r8loZt32o_1x2sgLVCTU'.freeze

  def initialize
    keyfile = Rails.root.join('config/credentials/cvparser-471707-ea26336728d2.json')
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(keyfile),
      scope: SCOPE
    )
    authorizer.fetch_access_token!
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorizer
  end

  def append_row(name:, email:, applied_for:, drive_url:, experience:,
                 sheet: 'Full Stack Software Engineer', skills:, experiences: [])
    range = "#{sheet}!A:G"

    formatted_skills =
      if skills.present?
        skills.split(',').map { |s| "\u2022 #{s.strip}" }.join("\n")
      else
        ''
      end

    experiences_text =
      if experiences.present?
        experiences.map { |exp| "\u2022 #{exp[:job_details]} (#{exp[:period]})" }.join("\n")
      else
        ''
      end
    values = [[name, email, applied_for, drive_url, experience.to_s, formatted_skills,
               experiences_text]]
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)

    @service.append_spreadsheet_value(
      SPREADSHEET_ID,
      range,
      value_range,
      value_input_option: 'RAW'
    )
  end

  def list_sheets
    spreadsheet = @service.get_spreadsheet(SPREADSHEET_ID)
    spreadsheet.sheets.map { |s| s.properties.title }
  end
end
