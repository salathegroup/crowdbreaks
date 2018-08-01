module Manage
  class ManagePagesController < BaseController
    before_action :api_init

    def dashboard
      @api_ready = @api.ping
      @status_all = @api.status_all
    end

    def streaming
      @stream_status = @api.status_streaming
      @current_streams = @api.get_config
      @is_up_to_date = Project.is_up_to_date(@current_streams)
      @projects = Project.all
    end

    def current_streams
      @current_streams = @api.get_config
    end

    def monitor_streams
      config = @api.get_config
      if config.empty?
        @current_streams = []
        return
      end
      @current_streams = Project.select(:title_translations, :es_index_name).where(slug: config.keys)
    end

    def sentiment_analysis_chart
      @interval = '6h'
      @project = Project.find_by('es_index_name': 'project_vaccine_sentiment')
    end

    def sentiment_analysis_map
      @project = Project.find_by('es_index_name': 'project_vaccine_sentiment')
    end

    def user_activity
      @interval = 'day'
    end

    private 

    def api_init
      @api = FlaskApi.new
    end
  end
end
