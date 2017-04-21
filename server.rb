require 'sinatra'
require 'net/http'
require 'dotenv/load'
require 'json'
require 'rest_client'
require 'tempfile'

enable :sessions

###########################
# DB
###########################

DB = { 'user@example.com' => '' }

def users
  DB.keys
end

def add_user(email)
  DB[email] = ''
end

def add_access_token(email, token)
  DB[email] = token
end

def access_token_for(email)
  DB[email]
end

def user_connected?(email)
  DB[email] != ''
end

###########################
# Rest
###########################

def rest_resource(path)
  uri = URI("#{ENV['API_HOST']}/api/#{path}")
  # Basic authentication is used with client id/secret
  RestClient::Resource.new(uri.to_s, ENV['CLIENT_ID'], ENV['CLIENT_SECRET'])
end


###########################
# Routes
###########################

get '/' do
  erb :index, locals: { users: users }
end


get '/anvandare/:email' do
  session[:user_email] = params[:email]
  erb :user, locals: { user: params[:email], connected: user_connected?(params[:email]) }
end


get '/ny-anvandare' do
  erb :new_user
end

get '/login/:email' do
  user_email = params[:email]
  # Access token is passed as an 'Access-Token' header
  res = rest_resource('login').get({'Access-Token' => access_token_for(user_email)})
  url = JSON.parse(res.body)['url']
  redirect to(url)
end

post '/ny-anvandare' do
  add_user(params[:email])
  redirect to('/')
end

post '/skapa-konto/:email' do
  user_email = params[:email]
  begin
    res = rest_resource('create_account').post({user_email: user_email}.to_json, {content_type: :json, accept: :json})
    access_token = JSON.parse(res.body)['access_token']
    add_access_token(user_email, access_token)
  rescue Exception
    session[:message] = 'Kunde inte skapa konto'
  end
  redirect to("/anvandare/#{user_email}")
end

post '/skapa-rapport/:email' do
  user_email = params[:email]
  sie_file = params[:sie_file][:tempfile]
  Tempfile.open('sie_file.se') do |utf8_encode_sie_file|
    utf8_encode_sie_file.write(sie_file.read.encode('UTF-8', 'IBM437'))
    utf8_encode_sie_file.close

    # Access token is passed as an 'Access-Token' header
    res = rest_resource('create_or_update_report').post({file: File.new(utf8_encode_sie_file.path)},
                                                        {'Access-Token' => access_token_for(user_email)})
    report_url = JSON.parse(res.body)['report_url']
    redirect to(report_url)
  end
end

get '/autentiserad' do
  user_email = session[:user_email]
  res = rest_resource('token').post({grant_type: 'authorization_code',
                                     code: params[:code],
                                     redirect_uri: "#{request.base_url}/autentiserad"}.to_json,
                                    {content_type: :json, accept: :json})
  access_token = JSON.parse(res.body)['access_token']
  add_access_token(user_email, access_token)
  redirect to("/anvandare/#{user_email}")
end