#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# file for a field to Sentera's FieldAgent platform using the
# import_files GraphQL mutation.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require '../utils/utils'
verify_ruby_version

require 'net/http'
require 'json'
require 'digest'
require '../utils/upload'

# If you want to debug this script, run the following gem install
# commands. Then uncomment the require statements below, and put
# debugger statements in the code to trace the code execution.
#
# > gem install pry
# > gem install pry-byebug
#
# require 'pry'
# require 'pry-byebug'

#
# This method demonstrates how to use the create_file_upload
# mutation in Sentera's GraphQL API to prepare a file
# for upload to Sentera's cloud storage.
#
# @param [string] file_path Path to file
# @param [string] content_type Content type of file
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_file_upload(file_path, content_type)
  puts 'Create file upload'

  gql = <<~GQL
    mutation CreateFileUpload(
      $byte_size: BigInt!
      $checksum: String!
      $content_type: String!
      $filename: String!
    ) {
      create_file_upload(
        byte_size: $byte_size
        checksum: $checksum
        content_type: $content_type
        filename: $filename
        ) {
        id
        headers
        upload_url
      }
    }
  GQL

  variables = {
    byte_size: File.size(file_path),
    checksum: Digest::MD5.base64digest(File.read(file_path)),
    content_type: content_type,
    filename: File.basename(file_path)
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_upload')
end

#
# This method demonstrates how to use the ID of the file that
# was previously uploaded to Sentera's cloud storage with the
# import_files GraphQL mutation, to attach the file to a field.
#
# @param [string] field_sentera_id Sentera ID of the field
#                                   within FieldAgent to attach
#                                   the file to.
# @param [Object] file_upload FileUpload GraphQL
#                        object created by the
#                        create_file_upload mutation
#
# @return [Hash] Hash containing results of the GraphQL request
#
def import_file(field_sentera_id, file_upload)
  puts 'Import file'

  gql = <<~GQL
    mutation ImportFile(
      $file_keys: [String!]!
      $file_type: FileType!
      $owner_type: FileOwnerType!
      $owner_sentera_id: ID!
    ) {
      import_files(
        file_keys: $file_keys
        file_type: $file_type
        owner_type: $owner_type
        owner_sentera_id: $owner_sentera_id
      ) {
        status
      }
    }
  GQL

  variables = {
    file_keys: [file_upload['id']],
    file_type: 'DOCUMENT',
    owner_type: 'FIELD',
    owner_sentera_id: field_sentera_id
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'import_files')
end

# MAIN

# **************************************************
# Set these variables based on the file you want
# to upload and the field within FieldAgent to
# which you want to attach the file
file_path = ENV.fetch('FILE_PATH', '../test_files/test.geojson') # Your fully qualified path to the file to upload
content_type = ENV.fetch('CONTENT_TYPE', 'application/json') # The content type of the file to upload
field_sentera_id = ENV.fetch('FIELD_SENTERA_ID', 'sezjmpa_AS_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your field Sentera ID
# **************************************************

# Step 1: Create a file upload for the file
file_upload = create_file_upload(file_path, content_type)
if file_upload.nil?
  puts 'Failed'
  exit
end

# Step 2: Upload the file
upload_file(file_upload, file_path)

# Step 3: Import the file into a field
results = import_file(field_sentera_id, file_upload)

if results
  puts "Done! File was queued for importing."
else
  puts 'Failed'
end
