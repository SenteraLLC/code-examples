# frozen_string_literal: true
require 'net/http'

#
# Loads the access token from a file on disk
#
# See https://api.sentera.com/api/getting_started/authentication_and_authorization.html
# for details on how to obtain an auth token to use with Sentera's GraphQL API
#
# @return [string] FieldAgent
#
def load_access_token
  return unless File.exist?(FIELDAGENT_ACCESS_TOKEN_FILENAME)

  File.read(FIELDAGENT_ACCESS_TOKEN_FILENAME)
end

#
# Makes a request to FieldAgent's GraphQL API
#
# @param [string] access_token FieldAgent access token
# @param [string] gql GraphQL query or mutation to request
#
# @return [Net::HTTP::Response] HTTP response object
#
def make_graphql_request(gql, variables = {})
  uri = URI(GQL_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = GQL_ENDPOINT.include?('https://')
  headers = {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{FIELDAGENT_ACCESS_TOKEN}"
  }
  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = { 'query': gql, variables: variables }.to_json

  puts "Make GraphQL request: uri = #{GQL_ENDPOINT}, gql = #{gql}, variables = #{variables}"
  response = http.request(request)
  puts "GraphQL response: code = #{response.code}, body = #{response.body}"

  response
end

GQL_ENDPOINT = ENV.fetch('FIELDAGENT_SERVER', 'https://api.sentera.com') + '/graphql' # Defaults to FieldAgent production

FIELDAGENT_ACCESS_TOKEN_FILENAME = 'fieldagent_access_token.txt'

FIELDAGENT_ACCESS_TOKEN = ENV.fetch('FIELDAGENT_ACCESS_TOKEN', load_access_token)
if FIELDAGENT_ACCESS_TOKEN.nil?
  raise <<~ERROR
    Unable to read your FieldAgent access token.
    Specify the access token using a FIELDAGENT_ACCESS_TOKEN environment variable,
    or, copy #{FIELDAGENT_ACCESS_TOKEN_FILENAME}.example to #{FIELDAGENT_ACCESS_TOKEN_FILENAME},
    replace the placeholder with your auth token, and then run again.
  ERROR
end
