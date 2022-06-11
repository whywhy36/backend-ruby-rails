# frozen_string_literal: true

class ApiController < ApplicationController
  before_action :set_message

  # nested_call_handler handles a "nested call" API.
  def nested_call_handler
    # Rails.logger.error { 'Test Test Crafting' }

    received_at = Time.current
    request = @message
    errors = []

    @message[:actions].each_with_index do |action, i|
      case action[:action]
      when 'Echo'
        @message[:actions][i][:status] = 'Passed'
      when 'Read'
        res = read_entity(action[:payload][:serviceName], action[:payload][:key])
        if res[:errors].present?
          errors << res[:errors]
          @message[:actions][i][:status] = 'Failed'
        else
          @message[:actions][i][:status] = 'Passed'
          @message[:actions][i][:payload][:value] = res[:value]
        end
      when 'Write'
        res = write_entity(action[:payload][:serviceName], action[:payload][:key], action[:payload][:value])
        if res[:errors].present?
          errors << res[:errors]
          @message[:actions][i][:status] = 'Failed'
        else
          @message[:actions][i][:status] = 'Passed'
        end
      when 'Call'
        resp = service_call(action[:payload])
        if resp.blank?
          errors << "failed to call service #{action[:payload][:serviceName]}"
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
    response = @message

    logger_logcontext(request, response, errors, received_at)

    render json: @message
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

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = false

      request = Net::HTTP::Post.new(url)
      request['Content-Type'] = 'application/json'
      request.body = message.to_json

      response = http.request(request)
      begin
        JSON.parse(response.read_body)
      rescue Exception => e
        nil
      end
    end

    def service_endpoint(serviceName)
      host = ''
      port = ''
      case serviceName
      when 'backend-go-gin'
        host = ENV.fetch('GIN_SERVICE_HOST', nil)
        port = ENV.fetch('GIN_SERVICE_PORT', nil)
      when 'backend-typescript-express'
        host = ENV.fetch('EXPRESS_SERVICE_HOST', nil)
        port = ENV.fetch('EXPRESS_SERVICE_PORT', nil)
      when 'backend-ruby-rails'
        host = ENV.fetch('RAILS_SERVICE_HOST', nil)
        port = ENV.fetch('RAILS_SERVICE_PORT', nil)
      when 'backend-kotlin-spring'
        host = ENV.fetch('SPRING_SERVICE_HOST', nil)
        port = ENV.fetch('SPRING_SERVICE_PORT', nil)
      when 'backend-python-django'
        host = ENV.fetch('DJANGO_SERVICE_HOST', nil)
        port = ENV.fetch('DJANGO_SERVICE_PORT', nil)
      end
      "http://#{host}:#{port}/api"
    end

    def read_entity(store, key)
      case store
      when 'mysql'
        read_mysql(key)
      when 'mongodb'
        read_mongodb(key)
      else
        { value: nil, errors: "#{store} not supported" }
      end
    end

    def write_entity(store, key, value)
      case store
      when 'mysql'
        write_mysql(key, value)
      when 'mongodb'
        write_mongodb(key, value)
      else
        { value: nil, errors: "#{store} not supported" }
      end
    end

    def read_mysql(key)
      value = Mysql.find_by(uuid: key)
      value = if value.blank?
                'Not Found'
              else
                value.content
              end
      { value: value, errors: nil }
    end

    def write_mysql(key, value)
      Mysql.create({ uuid: key, content: value })
      { value: value, errors: nil }
    end

    def read_mongodb(key)
      value = Mongodb.find_by(uuid: key)
      value = if value.blank?
                'Not Found'
              else
                value.content
              end
      { value: value, errors: nil }
    end

    def write_mongodb(key, value)
      Mongodb.create({ uuid: key, content: value })
      { value: value, errors: nil }
    end

    def logger_write(message)
      Rails.logger.error { message }
    end

    def logger_logcontext(request, response, errors, received_at)
      Rails.logger.error { "Started POST \"/api\" at #{received_at}" }
      Rails.logger.error { "  Request: #{request.as_json}" }
      Rails.logger.error { "  Response: #{response.as_json}" }
      Rails.logger.error { "  Errors: #{{ errors: errors }.as_json}" } if errors.length.positive?
      Rails.logger.error { "\n" }
    end
end
