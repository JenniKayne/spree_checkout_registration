Spree::CheckoutController.class_eval do
  after_action :create_user, only: [:update]

  def create_user
    return if @order.state != 'delivery' || params[:order][:create_account] != '1' || current_spree_user.present?

    user = create_user_prepare
    if user.save
      create_user_update_order(user)
      create_user_update_user(user)
      try(:create_user_update_custom_params, user)
      sign_in(user, scope: :user)
      flash[:success] = Spree.t('checkout_registration.user_created')
    else
      flash[:error] = create_user_error_message(user)
    end
  end

  private

  def create_user_prepare
    Spree::User.new(
      email: @order.email || params[:order][:email],
      password: params[:order][:password],
      password_confirmation: params[:order][:password_confirmation]
    )
  end

  def create_user_update_order(user)
    @order.update(user: user)
    @order.ship_address.update_attribute(:user_id, user.id)
    unless @order.shipping_eq_billing_address?
      @order.bill_address.update_attribute(:user_id, user.id)
    end
  end

  def create_user_update_user(user)
    user_update_params = {
      ship_address_id: @order.ship_address_id,
      bill_address_id: @order.bill_address_id
    }
    user_update_params[:firstname] = @order.bill_address.firstname if defined?(user.firstname)
    user_update_params[:lastname] = @order.bill_address.lastname if defined?(user.lastname)
    user.update user_update_params
  end

  def create_user_error_message(user)
    error_message = Spree.t('checkout_registration.user_not_created')
    error_message += ", #{user.errors.full_messages.join(', ')}" unless user.errors.blank?
    error_message
  end
end
