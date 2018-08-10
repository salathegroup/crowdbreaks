class LocalBatchJob < ApplicationRecord
  include ActiveModel::Validations

  extend FriendlyId
  friendly_id :name, use: :slugged

  has_and_belongs_to_many :users
  has_many :local_tweets, dependent: :delete_all
  belongs_to :project
  has_many :results

  validates :name, presence: true, uniqueness: {message: "Name must be unique"}
  validates_presence_of :project
  validates_with CsvValidator, fields: [:job_file]

  attr_accessor :job_file


  def assigned_to_user(user_id)
    results.where({
      local_batch_job_id: id,
      user_id: user_id
    })
  end

  def cleanup
    local_tweets.delete_all
  end

  def status
    return 'processing' if processing
    return 'deleting' if deleting
    return 'empty' if local_tweets.count == 0
    'ready'
  end

  def allows_user?(user_id)
    users.exists?(user_id) ? true : false
  end
end
