module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show update destroy]

      def index
        projects = Project.ordered.includes(:sections)
        projects = projects.active unless ActiveModel::Type::Boolean.new.cast(params[:include_archived])
        render json: { projects: serialize(projects.to_a) }
      end

      def show
        render json: serialize(@project)
      end

      def create
        project = Project.new(project_params)
        project.save ? render(json: serialize(project), status: :created) : render_validation_errors(project)
      end

      def update
        @project.update(project_params) ? render(json: serialize(@project)) : render_validation_errors(@project)
      end

      # Archive instead (PATCH archived: true) or move the tasks out first.
      def destroy
        if @project.tasks.kept.exists?
          render_error :conflict, "project_not_empty", "Move or delete this project's tasks first, or archive it."
        else
          @project.destroy!
          head :no_content
        end
      end

      private
        def set_project
          @project = Project.find(params[:id])
        end

        def project_params
          params.require(:project).permit(:name, :color, :icon, :position, :archived)
        end

        def serialize(projects)
          ids = Array(projects).map(&:id)
          open_task_counts = Task.kept.top_level.open.where(project_id: ids).group(:project_id).count
          ProjectResource.new(projects, params: { open_task_counts: }).to_h
        end
    end
  end
end
