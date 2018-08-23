module Manage
  class MturkBatchJobsController < BaseController
    load_and_authorize_resource

    def new
      @mturk_batch_job = MturkBatchJob.new
    end

    def index
      @mturk_batch_jobs = MturkBatchJob.all.order('created_at DESC').page(params[:page]).per(10)
    end

    def show
    end

    def edit
    end

    def update
      @mturk_batch_job = MturkBatchJob.find_by(id: params[:id])
      if @mturk_batch_job.update_attributes(mturk_batch_job_params)
        tweet_ids = retrieve_tweet_ids_from_job_file
        if @mturk_batch_job.job_file.present?
          # only overwrite if file was provided
          CreateTasksJob.perform_now(@mturk_batch_job.id, tweet_ids, destroy_first: true)
        end
        redirect_to(mturk_batch_jobs_path, notice: "Job '#{@mturk_batch_job.name}' is being updated...")
      else
        render :edit and return
      end
    end

    def create
      if @mturk_batch_job.save
        # generate tasks
        tweet_ids = retrieve_tweet_ids_from_job_file
        CreateTasksJob.perform_later(@mturk_batch_job.id, tweet_ids)
        redirect_to(mturk_batch_jobs_path, notice: "Job '#{@mturk_batch_job.name}' is being created...")
      else
        render :new and return
      end
    end

    def destroy
      unless @mturk_batch_job.present?
        redirect_to(mturk_batch_jobs_path, notice: "Job '#{@mturk_batch_job.name}' could not be found.")
      end
      destroy_results = false
      if params[:destroy_results].present?
        destroy_results = params[:destroy_results] == 'true' ? true : false
      end
      DestroyMturkBatchJob.perform_later(@mturk_batch_job.id, destroy_results: destroy_results)
      redirect_to(mturk_batch_jobs_path, notice: "Job '#{@mturk_batch_job.name}' is being destroyed...")
    end

    def submit
      mturk_batch_job = MturkBatchJob.find(params[:mturk_batch_job_id])
      if mturk_batch_job.status != 'unsubmitted'
        redirect_to(mturk_batch_jobs_path, alert: "Batch must be in 'unsubmitted' stated in order to be submitted.") and return
      end

      SubmitTasksJob.perform_later(mturk_batch_job.id)
      redirect_to(mturk_batch_jobs_path, notice: "HITs for batch #{mturk_batch_job.name} are being submitted...")
    end

    private

    def mturk_batch_job_params
      params.require(:mturk_batch_job).permit(:name, :title, :description, :keywords, :project_id, :number_of_assignments, :job_file, :reward, :lifetime_in_seconds, :auto_approval_delay_in_seconds, :assignment_duration_in_seconds, :sandbox, :instructions, :minimal_approval_rate)
    end

    def retrieve_tweet_ids_from_job_file
      if @mturk_batch_job.job_file.present?
        CSV.foreach(@mturk_batch_job.job_file.path).map{ |row| row[0] }
      else
        []
      end
    end
  end
end
