module Manage
  class MturkBatchJobsController < BaseController
    load_and_authorize_resource

    def new
    end

    def index
      @mturk_batch_jobs = MturkBatchJob.all.order('created_at DESC').page(params[:page]).per(10)
      if params[:requested_download_complete].present?
        flash[:success] = 'The requested file is now ready to download'
      end
    end

    def show
      respond_to do |format|
        format.html
        format.csv { 
          flash.clear
          s3 = AwsS3.new
          if s3.exists?(@mturk_batch_job.csv_file_path)
            redirect_to @mturk_batch_job.signed_csv_file_path
          else
            MturkBatchJobS3UploadJob.perform_later(@mturk_batch_job.id, current_user.id)
            redirect_to mturk_batch_jobs_path(requested_download: @mturk_batch_job.id)
          end
        }
      end
    end

    def edit
    end

    def update
      if @mturk_batch_job.update_attributes(mturk_batch_job_params)
        if @mturk_batch_job.job_file.present?
          # only overwrite if file was provided
          CreateTasksJob.perform_later(@mturk_batch_job.id, retrieve_tweet_rows_from_job_file, destroy_first: true)
        end
        redirect_to(mturk_batch_jobs_path, notice: "Job '#{@mturk_batch_job.name}' is being updated...")
      else
        render :edit and return
      end
    end

    def create
      @mturk_batch_job.sanitize_keywords!
      if @mturk_batch_job.save
        # generate tasks
        CreateTasksJob.perform_later(@mturk_batch_job.id, retrieve_tweet_rows_from_job_file)
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

    def clone
      mturk_batch_job_clone = MturkBatchJob.find(params[:clone_id])
      cloned_attributes = mturk_batch_job_clone.attributes.select{ |a| ['name', 'project_id', 'description', 'title', 'keywords', 'reward', 'lifetime_in_seconds', 'auto_approval_delay_in_seconds', 'assignment_duration_in_seconds', 'instructions', 'number_of_assignments', 'minimal_approval_rate', 'max_tasks_per_worker', 'check_availability'].include?(a)}
      @mturk_batch_job = MturkBatchJob.new(cloned_attributes)
      @mturk_batch_job.cloned_name = @mturk_batch_job.name
      @mturk_batch_job.name = @mturk_batch_job.name + '-copy'
      render :clone
    end


    private

    def mturk_batch_job_params
      params.require(:mturk_batch_job).permit(:name, :title, :description, :keywords, :project_id, :number_of_assignments, :job_file, :reward, :lifetime_in_seconds, :auto_approval_delay_in_seconds, :assignment_duration_in_seconds, :sandbox, :instructions, :minimal_approval_rate, :max_tasks_per_worker, :check_availability)
    end

    def retrieve_tweet_rows_from_job_file
      if @mturk_batch_job.job_file.present?
        CSV.foreach(@mturk_batch_job.job_file.path).map{ |row| row }
      else
        []
      end
    end
  end
end
