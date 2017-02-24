Spree::OrdersHelper.class_eval do
  def can_create_user_for_order(order, current_user)
    return true if current_user.blank? && !order.complete?
  end
end
