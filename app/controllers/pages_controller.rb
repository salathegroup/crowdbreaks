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
      bonus = Mturk.calculate_bonus(record.questions_answered)
      if bonus > 0
        message =  "Key was verfied successfully. You will receive an additional bonus of $#{bonus} upon approval of the assignment."
      else
        message =  "Key was verfied successfully. Thank you for your work."
      end
      record.update_attributes!(used: true, worker_id: params[:worker_id], assignment_id: params[:assignment_id])
      render json: {
        status: 200, # ok
        message: message
      }
    else
      render json: {
        status: 403, # forbidden
        message: "Key is not valid. Please make sure you enter the correct key."
      }
    end
  end
end
