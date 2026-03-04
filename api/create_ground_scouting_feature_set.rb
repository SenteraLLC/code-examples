#!/usr/bin/env ruby

# frozen_string_literal: true

# ==================================================================
# A Ruby example that demonstrates the workflow for uploading a
# feature set with annotations to Sentera's FieldAgent platform
# using the upsert_feature_set GraphQL mutation.
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

SOME = 'some'.freeze
ALL = 'all'.freeze
NONE = 'none'.freeze
SOME_ALL = [SOME, ALL].freeze


# If you want to debug this script, run the following gem install
# commands. Then uncomment the require statements below, and put
# debugger statements in the code to trace the code execution.
#
# > gem install pry
# > gem install pry-byebug
#
# require 'pry'
# require 'pry-byebug'


# Retrieves field information for a given survey.
#
# @param survey_sentera_id [String] The Sentera ID of the survey
# @return [Hash] Survey data including field sentera_id and bounding box
#
def get_field_by_survey(survey_sentera_id)
  puts 'Get field by survey'

  gql = <<~GQL
    query GetFieldBySurvey(
      $survey_sentera_id: ID!
    ) {
      survey(
        sentera_id: $survey_sentera_id
      ) {
        field {
          sentera_id
          bbox
        }
      }
    }
  GQL

  variables = {
    survey_sentera_id: survey_sentera_id
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'survey')
end

# Creates a GeoJSON feature collection with randomly distributed point features.
# The features can optionally include sample notes and attachment placeholders
# depending on the with_notes and with_attachments parameters.
#
# @param num_locations [Integer] Number of location features to generate
# @param bbox [Array<Float>] Bounding box coordinates [min_lon, min_lat, max_lon, max_lat]
# @param with_notes [String] Whether to add sample notes to each feature (NONE, SOME, ALL)
# @param with_attachments [String] Whether to prepare attachment placeholders (NONE, SOME, ALL)
# @return [Hash] GeoJSON FeatureCollection with generated features
#
def create_ground_scouting_geojson(
  num_locations:,
  bbox:,
  with_notes:,
  with_attachments:
)
  puts 'Create ground scouting GeoJSON'

  geojson = { type: 'FeatureCollection' }

  geojson[:features] = (1..num_locations).map do |location_num|
    longitude = rand(bbox[0]..bbox[2])
    latitude = rand(bbox[1]..bbox[3])

    has_note = with_notes == ALL || (with_notes == SOME && location_num.odd?)
    has_attachment = with_attachments == ALL || (with_attachments == SOME && location_num.even?)

    properties = {}
    properties[:notes] = "Sample note #{location_num}" if has_note
    properties[:attachments] = [] if has_attachment # Placeholder for attachments which will be added later

    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      properties: properties
    }
  end

  geojson
end

# Creates file upload records and obtains pre-signed S3 URLs for file uploads.
#
# @param file_props [Array<Hash>] Array of file property hashes, each containing:
#   - :filename [String] The name of the file
#   - :byte_size [Integer] The size of the file in bytes
#   - :checksum [String] The checksum of the file
#   - :content_type [String] The MIME type of the file
# @param survey_sentera_id [String] The Sentera ID of the parent survey
# @return [Array<Hash>] Array of file upload records with S3 URLs and headers
#
def create_file_uploads(file_props, survey_sentera_id)
  puts 'Create file uploads'

  files = file_props.map do |props|
    {
      filename: props[:filename],
      byte_size: props[:byte_size],
      checksum: props[:checksum],
      content_type: props[:content_type],
      file_type: 'IMAGE' # Set this as needed based on your file types
    }
  end

  gql = <<~GQL
    mutation CreateFileUploads(
      $file_upload_owner: FileUploadOwnerInput,
      $files: [FileUploadInput!]!
    ) {
      create_file_uploads(
        create_files: true
        file_upload_owner: $file_upload_owner
        files: $files
      ) {
        id
        owner_sentera_id
        headers
        s3_url
        upload_url
      }
    }
  GQL

  variables = {
    file_upload_owner: {
      owner_type: 'FEATURE_SET',
      parent_sentera_id: survey_sentera_id
    },
    files: files
  }

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'create_file_uploads')
end

# Uploads attachment files to S3 and associates them with GeoJSON features.
#
# @param survey_sentera_id [String] The Sentera ID of the parent survey
# @param attachment_props [Array<Hash>] An array of attachment property hashes, each containing:
#   - :path [String] The file path to upload as an attachment
#   - :filename [String] The name of the file
#   - :byte_size [Integer] The size of the file in bytes
#   - :checksum [String] The MD5 checksum of the file
#   - :content_type [String] The MIME type of the file
# @param num_attachments_per_feature [Integer] The number of attachments to add to each feature
# @param with_attachment_names [Boolean] Whether to include a "name" property in the attachment properties
# @param with_attachment_name_keys [Boolean] Whether to include a "name-key" property in the attachment properties
# @param geojson [Hash] GeoJSON FeatureCollection to which attachments will be added
# @return [String] The owner Sentera ID (feature set ID) from the file uploads
#
def upload_attachments(
  survey_sentera_id:,
  attachment_props:,
  num_attachments_per_feature:,
  with_attachment_names:,
  with_attachment_name_keys:,
  geojson:
)
  puts 'Upload attachments'

  file_uploads = create_file_uploads(attachment_props, survey_sentera_id)
  if file_uploads.nil? || file_uploads.empty?
    raise 'Failed to create file uploads'
  end

  attachment_file_paths = attachment_props.map { |prop| prop[:path] }
  upload_files(file_uploads, attachment_file_paths)

  geojson[:features].each_with_index do |feature, index|
    next unless feature[:properties].key?(:attachments) # Only add attachments to features that were designated to have them

    attachments = feature[:properties][:attachments]

    (0...num_attachments_per_feature).each do |offset|
      attachment_index = (index + offset) % attachment_props.length
      attachments << build_attachment(attachment_index, attachment_props, file_uploads,
                                      with_attachment_names, with_attachment_name_keys,
                                      offset)
    end
  end

  file_uploads.first['owner_sentera_id']
end

# Builds an attachment hash based on the file upload information and attachment properties.
#
# @param attachment_index [Integer] The index of the attachment in the attachment_props and file_uploads arrays
# @param attachment_props [Array<Hash>] An array of attachment property hashes
# @param file_uploads [Array<Hash>] An array of file upload records with S3 URLs
# @param with_attachment_names [Boolean] Whether to include a "name" property in the attachment properties
# @param with_attachment_name_keys [Boolean] Whether to include a "name-key" property in the attachment properties
# @param attachment_offset [Integer] The offset used for naming attachments when multiple attachments are added per feature
# @return [Hash] An attachment hash to be included in the GeoJSON feature's properties
#
def build_attachment(
  attachment_index,
  attachment_props,
  file_uploads,
  with_attachment_names,
  with_attachment_name_keys,
  attachment_offset
)
  attachment_prop = attachment_props[attachment_index]
  file_upload = file_uploads[attachment_index]

  attachment = {
    md5: attachment_prop[:checksum],
    mime: attachment_prop[:content_type],
    size: attachment_prop[:byte_size],
    s3_url: file_upload['s3_url']
  }
  attachment['name-key'] = "name_key_#{attachment_offset}" if with_attachment_name_keys
  attachment[:name] = "Name #{attachment_offset + 1}" if with_attachment_names

  return attachment
end

# Creates or updates a ground scouting feature set under a survey.
#
# @param geojson [Hash] GeoJSON FeatureCollection containing the features
# @param feature_set_sentera_id [String, nil] Optional existing feature set ID for upserting
# @param survey_sentera_id [String] The Sentera ID of the parent survey
# @return [Hash] Mutation result with succeeded and failed records
#
def upsert_ground_scouting_feature_set(
  geojson:,
  feature_set_sentera_id:,
  survey_sentera_id:,
  feature_set_name:
)
  puts 'Upsert ground scouting feature set'

  gql = <<~GQL
    mutation UpsertFeatureSet(
      $feature_set: FeatureSetImport!
      $owner: FeatureSetOwnerInput!
    ) {
      upsert_feature_set(
        feature_set: $feature_set
        owner: $owner
      ) {
        succeeded {
          ... on FeatureSet {
            sentera_id
            name
            type
            status
            released
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
      owner_type: 'SURVEY',
      sentera_id: survey_sentera_id
    },
    feature_set: {
      name: feature_set_name,
      type: "GROUND_SCOUTING",
      geometry: geojson,
      released: true
    }
  }

  # Only include sentera_id in the mutation if it's not nil. It's an optional field used for upserting.
  variables[:feature_set][:sentera_id] = feature_set_sentera_id if feature_set_sentera_id

  response = make_graphql_request(gql, variables)
  json = JSON.parse(response.body)
  json.dig('data', 'upsert_feature_set')
end


# MAIN

# **************************************************
# Set these variables based on the files you want
# to upload and the survey within FieldAgent to
# which you want to attach a feature set
feature_set_name = ENV.fetch('FEATURE_SET_NAME', nil) # The name of the feature set to create
num_locations = ENV.fetch('NUM_LOCATIONS', 5).to_i # The number of scouted locations (e.g.features) to create in the feature set
num_attachments_per_feature = ENV.fetch('NUM_ATTACHMENTS_PER_FEATURE', 1).to_i # The number of attachments to add per feature if WITH_ATTACHMENTS is some or all
with_notes = ENV.fetch('WITH_NOTES', NONE).downcase # Whether  all, some or no features have notes"
with_attachments = ENV.fetch('WITH_ATTACHMENTS', NONE).downcase # Whether all, some or no features have attachments
with_attachment_names= ENV.fetch('WITH_ATTACHMENT_NAMES', false) # Whether to include a "name" property in the attachment properties
with_attachment_name_keys= ENV.fetch('WITH_ATTACHMENT_NAME_KEYS', false) # Whether to include a "name-key" property in the attachment properties
attachments_path = ENV.fetch('ATTACHMENTS_PATH', nil) # The path to the attachments to upload. Required if WITH_ATTACHMENTS is some or all.
attachments_ext = ENV.fetch('ATTACHMENTS_EXT', nil) # Your file extension for the attachments to upload. Required if WITH_ATTACHMENTS is some or all.
survey_sentera_id = ENV.fetch('SURVEY_SENTERA_ID', nil) # Existing survey under which the ground scouting feature set will be created. Required to be provided.
# **************************************************

# Validate input variables
if survey_sentera_id.nil?
  raise 'SURVEY_SENTERA_ID environment variable must be specified'
end
if num_locations <= 0
  raise 'NUM_LOCATIONS environment variable must be greater than 0'
end
if SOME_ALL.include?(with_attachments) && attachments_path.nil?
  raise 'ATTACHMENTS_PATH environment variable must be specified if WITH_ATTACHMENTS is some or all'
end
if SOME_ALL.include?(with_attachments) && attachments_ext.nil?
  raise 'ATTACHMENTS_EXT environment variable must be specified if WITH_ATTACHMENTS is some or all'
end

attachment_props = []
if SOME_ALL.include?(with_attachments)
  attachment_props = read_file_props(attachments_path, attachments_ext)
  if attachment_props.empty?
    raise "No files found in ATTACHMENTS_PATH #{attachments_path} with extension #{attachments_ext}"
  end
end

# Step 1: Retrieve the survey's field's bounding box (e.g bbox)
survey = get_field_by_survey(survey_sentera_id)
if survey.nil? || survey['field'].nil?
  raise "Failed to retrieve field information for survey #{survey_sentera_id}"
end
field = survey['field']
bbox = field['bbox']

# Step 2: Create the ground scouting GeoJSON
geojson = create_ground_scouting_geojson(
  num_locations: num_locations,
  bbox: bbox,
  with_notes: with_notes,
  with_attachments: with_attachments
)

# Step 3: Upload attachments if WITH_ATTACHMENTS is some or all
feature_set_sentera_id = nil
if ['some', 'all'].include?(with_attachments)
  feature_set_sentera_id = upload_attachments(
    survey_sentera_id: survey_sentera_id,
    attachment_props: attachment_props,
    num_attachments_per_feature: num_attachments_per_feature,
    with_attachment_names: with_attachment_names,
    with_attachment_name_keys: with_attachment_name_keys,
    geojson: geojson
  )
  if feature_set_sentera_id.nil?
    raise 'Failed to upload attachments and create feature set'
  end
end

# Step 4: Update the ground scouting feature set with the GeoJSON
details = {
  num_locations: num_locations,
  with_attachments: with_attachments,
  attachment_ext: attachments_ext,
  num_attachments_per_feature: num_attachments_per_feature,
  with_attachment_names: with_attachment_names,
  with_attachment_name_keys: with_attachment_name_keys,
  with_notes: with_notes
}
feature_set_name = "Ground Scouting Feature Set - #{details}"
results = upsert_ground_scouting_feature_set(
  geojson: geojson,
  feature_set_sentera_id: feature_set_sentera_id,
  survey_sentera_id: survey_sentera_id,
  feature_set_name: feature_set_name
)
if results && results['succeeded'].any?
  feature_set = results['succeeded'][0]
  puts "Done! Ground scouting feature set #{feature_set['sentera_id']} was created with #{num_locations} locations."
else
  puts "Failed due to error: #{results['failed'].inspect}"
end
