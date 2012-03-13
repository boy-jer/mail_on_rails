class UsersController < ApplicationController
  
  def set_password
    @user = User.find(params[:id])
    if @user.check_password(params[:password])
      if params[:new_password] == params[:new_password_confirmation]
        @user.set_password(params[:new_password])
        render 'password_set'
      else
        redirect_to reset_path(@user.id), :notice => "new password and confirmation don't match, please try again."
      end
    else      
      redirect_to reset_path(@user.id), :notice => "your current password was not correct, please try again."
    end
  end
  
  def reset
    @user = User.find(params[:id])
  end
  
  def set_random_password
    @user = User.find(params[:id])
    if @user
      @user.set_random_password
    end
    
    redirect_to root_url
    
  end
  
  # GET /users
  # GET /users.json
  def index
    @users = User.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end

  # GET /users/1
  # GET /users/1.json
  def show
    if params[:email]
      @user = User.find_by_email(params[:email] + '.' + params[:format])
    else
      @user = User.find(params[:id])
    end
      
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user }
    end
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(params[:user])
    @user.email = @user.username + '@' + @user.domain.domain

    respond_to do |format|
      if @user.save
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render action: "new" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update
    @user = User.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.json { head :no_content }
    end
  end
end
