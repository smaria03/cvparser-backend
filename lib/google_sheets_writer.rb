require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetsWriter
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
  SPREADSHEET_ID = '1UihqJI_GpNIKvwg8gDz7pJ3r8loZt32o_1x2sgLVCTU'.freeze
  RANGE = 'Foaie1!A:E'.freeze

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

  def append_row(name:, email:, applied_for:, experience:)
    values = [[name, email, applied_for, '', experience.to_s]]
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)

    @service.append_spreadsheet_value(
      SPREADSHEET_ID,
      RANGE,
      value_range,
      value_input_option: 'RAW'
    )
  end
end
