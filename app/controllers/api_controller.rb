# frozen_string_literal: true

class ApiController < ApplicationController
  before_action :set_message

  # POST /
  def NestedCallHandler
    render json: @message
  end

  private

    def set_message
      @message = {
        meta: params[:meta],
        actions: params[:actions]
      }
    end
end
