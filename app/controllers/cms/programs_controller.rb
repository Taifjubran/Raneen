class Cms::ProgramsController < ApplicationController
  before_action :authenticate_cms!
  before_action :set_program, only: [:show, :edit, :update, :destroy, :upload]
  
  def index
    @programs = Program.all.order(created_at: :desc)
    @pagy, @programs = pagy(@programs)
  end

  def show
  end

  def new
    @program = Program.new
  end

  def create
    @program = Program.new(program_params)
    
    if @program.save
      respond_to do |format|
        format.html { redirect_to cms_program_path(@program), notice: 'Program created successfully!' }
        format.json { render json: { id: @program.id, status: 'created' }, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @program.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @program.update(program_params)
      redirect_to cms_program_path(@program), notice: 'Program updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @program.destroy
    redirect_to cms_programs_path, notice: 'Program deleted successfully!'
  end
  
  def upload
    # Handle file upload via AJAX
    respond_to do |format|
      format.html { redirect_to cms_program_path(@program) }
      format.json { render json: { program_id: @program.id } }
    end
  end

  private

  def set_program
    @program = Program.find(params[:id])
  end

  def program_params
    # Allow published_at to be set for publishing
    params.require(:program).permit(:title, :description, :kind, :language, :category, :published_at, tags: [])
  end
end
