class PagesController < ApplicationController
  skip_before_action :verify_authenticity_token, :only => [:mturk_tokens]

  def index
  end

  def about
  end

  def test
  end

  def es_test
    client = Crowdbreaks::Client
    @resp = client.cluster.health
    render :test
  end

  def mturk_tokens
    unless params[:token].present? and params[:key].present?
      render json: {
        status: 400, # bad request
        message: "Key not present. Complete the task and fill in the provided key before submitting."
      }
      return
    end

    # existence test for key pair
    record = MturkToken.find_by(token: params[:token], key: params[:key], used: false)
    if record.present?
      begin
        # This should probably run in a background job...
        Mturk.grant_bonus(assignment_id: params[:assignment_id], worker_id: params[:worker_id], num_questions_answered: record.questions_answered)
      rescue
        puts "COULD NOT SEND BONUS"
      else
        record.update_attributes!(bonus_sent: true) 
      ensure
        record.update_attributes!(worker_id: params[:worker_id], assignment_id: params[:assignment_id])
      end
      render json: {
        status: 200, # ok
        message: "Key was verfied successfully. You were automatically granted a bonus."
      }
    else
      render json: {
        status: 403, # forbidden
        message: "Key is not valid. Please make sure you enter the correct key."
      }
    end
  end
end
