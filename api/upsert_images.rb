#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading images
# to Sentera's FieldAgent platform using the create_file_uploads
# and upsert_images GraphQL mutations.
#
# Contact devops@sentera.com with any questions.
# ==================================================================

require '../utils/utils'
verify_ruby_version

require 'net/http'
require 'json'
require 'digest'
require '../utils/parallel'
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
# This method demonstrates how to use the create_image_uploads
# mutation in Sentera's GraphQL API to prepare images for
# upload to Sentera's cloud storage.
#
# @param [Array[Hash]] image_props Array of image properties
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent that will
#                                   be the parent of the images.
# @param [string] sensor_type The type of sensor that captured the images
#
# @return [Hash] Hash containing results of the GraphQL request
#
def create_image_uploads(image_props, survey_sentera_id, sensor_type)
  puts 'Create image uploads'

  images = image_props.map do |props|
    {
      filename: props[:filename],
      byte_size: props[:byte_size],
      checksum: props[:checksum],
      content_type: props[:content_type],
      sensor_type: sensor_type
    }
  end

  gql = <<~GQL
    mutation CreateImageUploads(
      $survey_sentera_id: ID!,
      $images: [ImageUploadInput!]!
    ) {
      create_image_uploads(
        survey_sentera_id: $survey_sentera_id
        images: $images
      ) {
        id
        headers
        s3_url
        upload_url
      }
    }
  GQL

  variables = {
    survey_sentera_id: survey_sentera_id,
    images: images
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_image_uploads')
end

#
# This method demonstrates how to use the IDs of the images that
# were previously uploaded to Sentera's cloud storage with the
# upsert_images GraphQL mutation.
#
# @param [string] survey_sentera_id Sentera ID of the survey
#                                   within FieldAgent to create
#                                   the images under
# @param [Array[Object]] image_uploads ImageUpload GraphQL
#                        objects created by the
#                        create_image_uploads mutation
# @param [string] sensor_type The type of sensor that captured the images
# @param [Array[Hash]] image_props Array of image properties
#
# @return [Hash] Hash containing results of the GraphQL request
#
def upsert_images(survey_sentera_id, image_uploads, sensor_type, image_props)
  puts 'Upsert images'

  gql = <<~GQL
    mutation UpsertImages(
      $survey_sentera_id: ID!
      $images: [ImageImport!]!
    ) {
      upsert_images(
        survey_sentera_id: $survey_sentera_id
        images: $images
      ) {
        succeeded {
          ... on Image {
            sentera_id
            filename
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
    survey_sentera_id: survey_sentera_id,
    images: image_uploads.map do |image_upload|
      filename = File.basename(image_upload['s3_url'])
      props = image_props.find { |p| p[:filename] == filename }

      {
        # The following attributes are required when creating images
        # using the upsert_images mutation. Adjust as needed.
        # Note the use of the file_key attribute to reference
        # the previously uploaded image.
        altitude: 0,
        calculated_index: 'UNKNOWN',
        captured_at: Time.now.utc.iso8601,
        color_applied: 'UNKNOWN',
        filename: filename,
        key: image_upload['id'],
        gps_carrier_phase_status: 'STANDARD',
        gps_horizontal_accuracy: 0,
        gps_vertical_accuracy: 0,
        latitude: 0,
        longitude: 0,
        sensor_type: sensor_type,
        size: props[:byte_size]
      }
    end
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'upsert_images')
end

# MAIN

# **************************************************
# Set these variables based on the images you want
# to upload and the survey within FieldAgent to
# create the images under.
images_path = ENV.fetch('IMAGES_PATH', '.') # Your fully qualified path to a folder containing the images to upload
file_ext = ENV.fetch('FILE_EXT', '*.*') # Your image file extension
sensor_type = ENV.fetch('SENSOR_TYPE', 'UNKNOWN') # Your sensor type for the images being uploaded
survey_sentera_id = ENV.fetch('SURVEY_SENTERA_ID', nil) # Your existing survey Sentera ID
# **************************************************

unless File.exist?(images_path)
  raise "IMAGES_PATH #{images_path} does not exist"
end

if survey_sentera_id.nil?
  raise 'SURVEY_SENTERA_ID environment variable must be specified'
end

# Step 1: Create image uploads for the images
image_props = read_file_props(images_path, file_ext)
image_uploads = create_image_uploads(image_props, survey_sentera_id, sensor_type)
if image_uploads.nil?
  puts 'Failed'
  exit
end

# Step 2: Upload the images
image_paths = image_props.map { |props| props[:path] }
upload_files(image_uploads, image_paths)

# Step 3: Create images in FieldAgent using the uploaded images
results = upsert_images(survey_sentera_id, image_uploads, sensor_type, image_props)

if results && results['succeeded'].any?
  puts "Done! Images for #{survey_sentera_id} were created in FieldAgent."
else
  puts "Failed due to error: #{results['failed'].inspect}"
end
