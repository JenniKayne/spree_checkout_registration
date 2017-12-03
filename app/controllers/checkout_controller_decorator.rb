Spree::CheckoutController.class_eval do
  before_action :save_user_to_create, only: [:update]
  before_action :verify_updated_user_to_create, only: [:update]
  before_action :load_order_create_user, only: [:edit]

  after_action :create_user, only: [:update]

  def create_user
    return if !@order.completed?

    load_order_create_user
    if !@order_create_user.blank?
      user = Spree::User.new(
        email: @order.email,
        password: @order_create_user['password'],
        password_confirmation: @order_create_user['password']
      )

      if user.save
        flash[:success] = Spree.t('checkout_registration.user_created')
        @order.update(user: user)

        if @order.shipping_eq_billing_address?
          @order.ship_address.update_attribute(:user_id, user.id)
        else
          @order.ship_address.update_attribute(:user_id, user.id)
          @order.bill_address.update_attribute(:user_id, user.id)
        end

        user.update(
          ship_address_id: @order.ship_address_id,
          bill_address_id: @order.bill_address_id
        )

        sign_in(user, scope: :user)
      else
        Spree.t('checkout_registration.user_not_created')
        flash[:error] = Spree.t('checkout_registration.user_not_created')
        flash[:error] += ', ' + user.errors.full_messages.join(', ') unless user.errors.blank?
      end
    end
  end

  def save_user_to_create
    return if @order.state != 'address' || current_spree_user.present?

    if params[:create_account] != '1'
      clear_order_create_user
    else
      user = Spree::User.new(
        email: @order.email || params[:order][:email],
        password: params[:password],
        password_confirmation: params[:password_confirmation]
      )

      if user.valid?
        set_order_create_user(params[:password])
      else
        clear_order_create_user
        flash[:error] = user.errors.full_messages.join(', ') unless user.errors.blank?
        redirect_to checkout_state_path(@order.state)
      end
    end
  end

  def verify_updated_user_to_create
    return if params[:order].blank? || params[:order][:email].blank? || params[:order][:email] == @order.email

    load_order_create_user
    if !@order_create_user.blank?
      user = Spree::User.new(
        email: params[:order][:email],
        password: @order_create_user['password'],
        password_confirmation: @order_create_user['password']
      )

      if user.valid?
        set_order_create_user(@order_create_user['password'])
      else
        clear_order_create_user
        flash[:error] = user.errors.full_messages.join(', ') unless user.errors.blank?
        redirect_to :back
      end
    end
  end

  private

  def load_order_create_user
    @order_create_user = session[:order_create_user] if current_spree_user.blank? &&
                                                        !session[:order_create_user].blank? &&
                                                        session[:order_create_user]['order_number'] == @order.number
  end

  def set_order_create_user(password)
    session[:order_create_user] = {
      'order_number' => @order.number,
      'password' => password
    }
  end

  def clear_order_create_user
    session[:order_create_user] = nil
  end
end
