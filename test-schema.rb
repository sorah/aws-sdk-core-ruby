#!/usr/bin/env ruby

require 'json'
require 'json-schema'

{
  " S3" => 'apis/source/s3-2006-03-01.resources.json',
  "EC2" => 'apis/source/ec2-2014-02-01.resources.json',
  "IAM" => 'apis/source/iam-2010-05-08.resources.json',
  "SQS" => 'apis/source/sqs-2012-11-05.resources.json',
  "SNS" => 'apis/source/sns-2010-03-31.resources.json',
}.each do |svc, path|
  json = JSON.load(File.read(path))
  errors = JSON::Validator.fully_validate('resources.schema.json', json)
  if errors.empty?
    puts "#{svc}: OK"
  else
    puts "#{svc}: ERRORS"
    puts " -  " + errors.join("\n -  ")
  end
end
