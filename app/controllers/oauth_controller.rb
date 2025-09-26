require 'googleauth'
require 'googleauth/stores/file_token_store'

class OauthController < ApplicationController
  CLIENT_SECRETS_PATH = Rails.root.join('config/credentials/oauth_client_secret.json')
  TOKEN_STORE_PATH = Rails.root.join('config/credentials/tokens.yaml')
  USER_ID = 'default'.freeze

  def authorize
    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_STORE_PATH.to_s)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

    credentials = authorizer.get_credentials(USER_ID)

    if credentials.nil?
      redirect_uri = oauth2_callback_url
      url = authorizer.get_authorization_url(
        base_url: redirect_uri,
        request: request,
        redirect_uri: redirect_uri
      )
      redirect_to url
    else
      session[:google_auth] = credentials.to_json
      redirect_to 'http://localhost:3001/upload'
    end
  end

  def callback
    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_STORE_PATH.to_s)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: USER_ID,
      code: params[:code],
      base_url: oauth2_callback_url
    )

    session[:google_auth] = credentials.to_json
    redirect_to 'http://localhost:3001/upload'
  end

  private

  def scope
    [
      Google::Apis::DriveV3::AUTH_DRIVE_FILE,
      Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    ]
  end
end
