class ImagesController < ApplicationController
  before_action :set_image, only: [ :show ]

  def index
    @images = Image.completed.order(created_at: :desc).limit(10)
  end

  def show
    # Show by share token
  end

  def new
    @image = Image.new
  end

  def create
    @image = Image.new(image_params)

    if @image.save
      # Process the image asynchronously (for now, we'll do it synchronously)
      begin
        ImageProcessingService.new(@image).process!
        redirect_to shared_image_path(@image.share_token), notice: "Image was successfully processed!"
      rescue => e
        @image.update(status: "failed")
        redirect_to new_image_path, alert: "Failed to process image. Please try again."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def shared
    @image = Image.find_by_share_token!(params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Image not found."
  end

  def download
    @image = Image.find_by_share_token!(params[:token])

    if params[:type] == "paint_by_number" && @image.paint_by_number_image.attached?
      redirect_to rails_blob_path(@image.paint_by_number_image, disposition: "attachment")
    elsif @image.pixelated_image.attached?
      redirect_to rails_blob_path(@image.pixelated_image, disposition: "attachment")
    else
      redirect_to shared_image_path(@image.share_token), alert: "Download not available."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Image not found."
  end

  private

  def set_image
    @image = Image.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Image not found."
  end

  def image_params
    params.require(:image).permit(:title, :original_image)
  end
end
