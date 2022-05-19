# frozen_string_literal: true

class Mongodb
  include Mongoid::Document
  include Mongoid::Timestamps

  field :uuid, type: String
  field :content, type: String

  store_in collection: 'sample'
end
