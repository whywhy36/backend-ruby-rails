# frozen_string_literal: true

class ApiController < ApplicationController
  before_action :set_message

  # nested_call_handler handles a "nested call" API.
  # Accepts POST requests with a JSON body specifying
  # the nested call, and returns the response json.
  def nested_call_handler
    @message[:actions].each_with_index do |action, i|
      case action[:action]
      when 'Echo'
        @message[:actions][i][:status] = 'Passed'
      when 'Read'
        value = read_entity(action[:payload][:serviceName], action[:payload][:key])
        if value.blank?
          @message[:actions][i][:status] = 'Failed'
        else
          @message[:actions][i][:status] = 'Passed'
          @message[:actions][i][:payload][:value] = value
        end
      when 'Write'
        value = write_entity(action[:payload][:serviceName], action[:payload][:key], action[:payload][:value])
        @message[:actions][i][:status] = if value.blank?
                                           'Failed'
                                         else
                                           'Passed'
                                         end
      when 'Call'
        resp = service_call(action[:payload])
        if resp.blank?
          @message[:actions][i][:status] = 'Failed'
        else
          @message[:actions][i][:status] = 'Passed'
          @message[:actions][i][:payload][:actions] = resp['actions']
        end
      end

      @message[:actions][i][:serviceName] = 'backend-ruby-rails'
      @message[:actions][i][:returnTime] = Time.current
    end

    @message[:meta][:returnTime] = Time.current

    Rails.logger.debug { "  Response: #{@message.as_json}" }

    render json: @message

    # TODO: persist response
    # write payload to kafka queue for react topic
  end

  private

    def set_message
      @message = {
        meta: params[:meta],
        actions: params[:actions]
      }
    end

    def service_call(payload)
      message = {
        meta: {
          caller: 'backend-ruby-rails',
          callee: payload[:serviceName],
          callTime: Time.current
        },
        actions: payload[:actions]
      }

      require 'uri'
      require 'json'
      require 'net/http'

      url = URI(service_endpoint(payload[:serviceName]))

      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(url)
      request['Content-Type'] = 'application/json'
      request.body = message.to_json

      response = https.request(request)
      JSON.parse(response.read_body)
    end

    def service_endpoint(serviceName)
      suffix = ENV.fetch('SANDBOX_ENDPOINT_DNS_SUFFIX', nil)
      case serviceName
      when 'backend-go-gin'
        "https://gin#{suffix}/api"
      when 'backend-typescript-express'
        "https://express#{suffix}/api"
      when 'backend-ruby-rails'
        "https://rails#{suffix}/api"
      when 'backend-kotlin-spring'
        "https://spring#{suffix}/api"
      when 'backend-python-django'
        "https://django#{suffix}/api"
      else
        'unknown'
      end
    end

    def read_entity(_store, _key)
      # TODO:
      # If success, return value
      # If error, log and return nil
      'TODO'
    end

    def write_entity(_store, _key, _value)
      # TODO:
      # If success, return value back
      # If error, log and return nil
      'TODO'
    end
end
