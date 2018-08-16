class AdminAbility
  include CanCan::Ability

  # Defines all abilities under /admin namespace

  def initialize(user)
    user ||= User.new
    if user.admin?
      can :manage, :all
    elsif user.collaborator?
      can :view, :dashboard
      can :manage, Project
      cannot :destroy, Project
      can :manage, :question_sequence
    elsif user.contributor?
      # to be specified
    end
  end
end
