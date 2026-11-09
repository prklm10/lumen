module Api
  module V1
    class FoldersController < BaseController
      before_action :set_folder, only: %i[update destroy]

      # Flat list; the UI builds the tree from parent_id.
      def index
        render json: { folders: FolderResource.new(Folder.order(:position, :id)).to_h }
      end

      def create
        folder = Folder.new(folder_params)
        folder.save ? render(json: FolderResource.new(folder).to_h, status: :created) : render_validation_errors(folder)
      end

      def update
        @folder.update(folder_params) ? render(json: FolderResource.new(@folder).to_h) : render_validation_errors(@folder)
      end

      # Its subfolders and notes move up to the parent folder.
      def destroy
        @folder.dissolve!
        head :no_content
      end

      private
        def set_folder
          @folder = Folder.find(params[:id])
        end

        def folder_params
          params.require(:folder).permit(:name, :parent_id, :position)
        end
    end
  end
end
