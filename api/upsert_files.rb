#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# file for a field to Sentera's FieldAgent platform using the
# upsert_files GraphQL mutation.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require '../utils/utils'
verify_ruby_version

require 'net/http'
require 'json'
require 'digest'


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
# mutation in Sentera's GraphQL API to prepare a file for
# upload to Sentera's cloud storage.
#
# @param [string] file_path Path to file
# @param [string] content_type Content type of file
# @param [string] field_sentera_id Sentera ID of the field
#                                   within FieldAgent that the
#                                   file will be attached.
# @param [string] organization_sentera_id Sentera ID of the organization
#                                   within FieldAgent that owns
#                                   the specified field.
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_file_upload(file_path, content_type, field_sentera_id, organization_sentera_id)
  puts 'Create file upload'

  gql = <<~GQL
    mutation CreateFileUpload(
      $byte_size: BigInt!
      $checksum: String!
      $content_type: String!
      $filename: String!
      $file_upload_owner: FileUploadOwnerInput
    ) {
      create_file_upload(
        byte_size: $byte_size
        checksum: $checksum
        content_type: $content_type
        filename: $filename
        file_upload_owner: $file_upload_owner
        ) {
        id
        headers
        owner_sentera_id
        upload_url
      }
    }
  GQL

  variables = {
    byte_size: File.size(file_path),
    checksum: Digest::MD5.base64digest(File.read(file_path)),
    content_type:,
    filename: File.basename(file_path),
    file_upload_owner: {
      owner_type: 'FIELD',
      owner_sentera_id: field_sentera_id,
      parent_sentera_id: organization_sentera_id
    }
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_upload')
end

#
# This method demonstrates how to upload a file to
# Sentera's cloud storage using the URL and headers
# that were retrieved via the create_file_upload
# GraphQL mutation.
#
# @param [Object] file_upload FileUpload GraphQL
#                        object created by the
#                        create_file_upload mutation
# @param [string] file_path Path of the file to upload
#
# @return [void]
#
def upload_file(file_upload, file_path)
  puts 'Upload file'

  uri = URI(file_upload['upload_url'])
  file_contents = File.read(file_path)
  Net::HTTP.start(uri.host) do |http|
    puts "Upload #{file_path} to S3"
    response = http.send_request('PUT',
                                  uri,
                                  file_contents,
                                  file_upload['headers'])
    puts "Done uploading #{file_path}, response.code = #{response.code}"
  end
end

#
# This method demonstrates how to use the ID of the file that
# was previously uploaded to Sentera's cloud storage with the
# upsert_files GraphQL mutation, to attach the file to a field.
#
# @param [string] field_sentera_id Sentera ID of the field
#                                   within FieldAgent to attach
#                                   the file to.
# @param [Object] file_upload FileUpload GraphQL
#                        object created by the
#                        create_file_upload mutation
# @param [string] file_path Path of the file to upload
#
# @return [Hash] Hash containing results of the GraphQL request
#
def upsert_file(field_sentera_id, file_upload, file_path)
  puts 'Upsert file'

  gql = <<~GQL
    mutation UpsertFile(
      $files: [FileImport!]!
      $owner: FileOwnerInput!
    ) {
      upsert_files(
        files: $files
        owner: $owner
      ) {
        succeeded {
          ... on File {
            sentera_id
          }
        }
        failed {
          attributes {
            key
            details
            attribute
          }
        }
      }
    }
  GQL

  variables = {
    owner: {
      sentera_id: field_sentera_id,
      owner_type: 'FIELD'
    },
    files: [
      {
        file_key: file_upload['id'],
        file_type: 'DOCUMENT',
        filename: File.basename(file_path),
        path: "#{field_sentera_id}\\Files",
        size: File.size(file_path),
        version: 1
      }
    ]
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'upsert_files')
end

# MAIN

# **************************************************
# Set these variables based on the file you want
# to upload and the field within FieldAgent to
# which you want to attach the file
file_path = ENV.fetch('FILE_PATH', '../test_files/test.geojson') # Your fully qualified path to the file to upload
content_type = ENV.fetch('CONTENT_TYPE', 'application/json') # The content type of the file to upload
field_sentera_id = ENV.fetch('FIELD_SENTERA_ID', 'sezjmpa_AS_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your field Sentera ID
organization_sentera_id = ENV.fetch('ORGANIZATION_SENTERA_ID', 'vbepojk_OR_arpmAcmeOrg_CV_deve_b822f1701_230330_110124') # Your field Sentera ID
# **************************************************

# Step 1: Create a file upload for the file
file_upload = create_file_upload(file_path, content_type, field_sentera_id, organization_sentera_id)
if file_upload.nil?
  puts 'Failed'
  exit
end

# Step 2: Upload the file
upload_file(file_upload, file_path)

# Step 3: Upsert the file, which will associate it to the field
results = upsert_file(field_sentera_id, file_upload, file_path)

if results && results['succeeded'].any?
  file_sentera_id = results['succeeded'][0]['sentera_id']
  puts "Done! File #{file_sentera_id} was created and attached to field #{field_sentera_id}."
else
  puts "Failed due to error: #{results['failed'].inspect}"
end
