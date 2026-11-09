module Api
  module V1
    class SectionsController < BaseController
      before_action :set_project
      before_action :set_section, only: %i[update destroy]

      def create
        section = @project.sections.new(section_params)
        section.save ? render(json: SectionResource.new(section).to_h, status: :created) : render_validation_errors(section)
      end

      def update
        @section.update(section_params) ? render(json: SectionResource.new(@section).to_h) : render_validation_errors(@section)
      end

      # Its tasks move to the project root (tasks.section_id is ON DELETE SET NULL).
      def destroy
        @section.destroy!
        head :no_content
      end

      private
        def set_project
          @project = Project.find(params[:project_id])
        end

        def set_section
          @section = @project.sections.find(params[:id])
        end

        def section_params
          params.require(:section).permit(:name, :position)
        end
    end
  end
end
