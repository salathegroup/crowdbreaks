require 'httparty'

class FlaskApi
  include HTTParty
  include Ml
  include Pipeline
  include Elasticsearch

  default_timeout 5
  base_uri ENV['FLASK_API_HOSTNAME']
  # debug_output $stderr
  basic_auth ENV['FLASK_API_USERNAME'], ENV['FLASK_API_PASSWORD']
  JSON_HEADER = {'Content-Type' => 'application/json', :Accept => 'application/json'}


  def initialize
  end

  def ping
    options = {timeout: 5}
    handle_error(error_return_value: false) do
      resp = self.class.get("/", options)
      resp.success?
    end
  end

  def test_redis
    options = {timeout: 5}
    handle_error(error_return_value: false) do
      resp = self.class.get("/test/redis", options)
      resp.parsed_response == 'true'
    end
  end

  # tweets
  def get_tweet(es_index_name, user_id: nil)
    data = {'user_id': user_id}
    tweet = nil
    handle_error do
      resp = self.class.get('/tweet/new/'+es_index_name, query: data, timeout: 2)
      tweet = resp.parsed_response.deep_symbolize_keys!
    end
    tweet
  end

  def remove_tweet(es_index_name, tweet_id)
    data = {'tweet_id': tweet_id}
    handle_error do
      self.class.post('/tweet/remove/'+es_index_name, body: data.to_json, headers: JSON_HEADER)
    end
  end

  def update_tweet(es_index_name, user_id, tweet_id)
    data = {'user_id': user_id, 'tweet_id': tweet_id}
    handle_error do
      self.class.post('/tweet/update/'+es_index_name, body: data.to_json, headers: JSON_HEADER)
    end
  end

  def get_trending_tweets(project_slug, options={})
    handle_error(error_return_value: []) do
      resp = self.class.get('/trending_tweets/'+project_slug, body: options.to_json, timeout: 10, headers: JSON_HEADER)
      resp.parsed_response
    end
  end

  def get_trending_topics(project_slug, options={})
    handle_error(error_return_value: []) do
      resp = self.class.get('/trending_topics/'+project_slug, body: options.to_json, timeout: 10, headers: JSON_HEADER)
      resp.parsed_response
    end
  end

  # elasticsearch - all data
  def get_all_data(index, options={}, use_cache=true)
    cache_key = "get-all-data-#{index}-#{options.to_s}"
    cached(cache_key, use_cache=use_cache) do
      handle_error(error_return_value: []) do
        resp = self.class.get('/data/all/'+index, body: options.to_json, timeout: 20, headers: JSON_HEADER)
        JSON.parse(resp)
      end
    end
  end

  # elasticsearch - sentiment data
  def get_sentiment_data(value, options={}, use_cache=true)
    cache_key = "get-sentiment-data-#{value}-#{options.to_s}"
    cached(cache_key, use_cache=use_cache) do
      handle_error(error_return_value: []) do
        resp = self.class.get('/sentiment/data/'+value, query: options, timeout: 20)
        JSON.parse(resp)
      end
    end
  end

  def get_avg_sentiment(options={})
    handle_error(error_return_value: []) do
      resp = self.class.get('/sentiment/average', query: options, timeout: 20)
      JSON.parse(resp)
    end
  end

  def get_vaccine_sentiment(text)
    data = {'text': text, model_endpoint: 'crowdbreaks-2da2332569'}
    handle_error do
      self.class.post('/ml/predict', body: data.to_json, headers: JSON_HEADER)
    end
  end

  def get_geo_sentiment(options={})
    handle_error(error_return_value: []) do
      resp = self.class.get('/sentiment/geo', query: options, timeout: 20)
      JSON.parse(resp)
    end
  end

  # email status
  def get_streaming_email_status(type: 'weekly')
    options = {type: type}
    handle_error(error_return_value: '') do
      resp = self.class.get('/email/status', query: options, timeout: 20)
      resp.parsed_response
    end
  end


  private

  def cached(cache_key, use_cache=false, cache_duration=5.minutes)
    # by default don't use cache
    return yield unless use_cache
    # use cache
    if Rails.cache.exist?(cache_key)
      Rails.logger.info("Reading from cache key #{cache_key}")
      return Rails.cache.read(cache_key)
    else
      resp = yield
      unless resp.nil? or resp == [] or resp == {}
        Rails.logger.info("Setting cache key #{cache_key}")
        Rails.cache.write(cache_key, resp, expires_in: cache_duration)
      end
      resp
    end
  end

  def handle_error(error_return_value: nil)
    begin
      yield
    rescue StandardError => e
      error_return_value
    end
  end

  def handle_error_notification(message: 'An error occured')
    begin
      yield
    rescue StandardError => e
      Hashie::Mash.new({success: false, parsed_response: message, code: 400})
    end
  end
end
