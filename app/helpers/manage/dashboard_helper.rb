module Manage::DashboardHelper
  def label_based_on_status(status)
    if status == 'running' or status == 'paused'
      image_tag(status+'.svg') + ' ' + status
    else
      image_tag('not-running.svg') + ' ' + status
    end
  end

  def label_up_to_date(status)
    if status
      image_tag('running.svg') + ' Up-to-date'
    else
      image_tag('not-running.svg') + ' Not up-to-date'
    end
  end
end
