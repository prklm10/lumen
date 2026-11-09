module Api
  module V1
    class SearchesController < BaseController
      def show
        render json: SearchQuery.new(params[:q]).call
      end
    end
  end
end
