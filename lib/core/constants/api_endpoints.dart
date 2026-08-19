class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = "http://localhost/billing_api";

  // Auth
  static const String login = "$baseUrl/Auth/login";
  static const String addAbsensi = "$baseUrl/Auth/add_absensi";

  // Master user
  static const String userList = "$baseUrl/Master/user_list";
  static const String addUser = "$baseUrl/Master/add_user";
  static const String editUser = "$baseUrl/Master/edit_user";
  static const String deleteUser = "$baseUrl/Master/delete_user";
  static const String resetPasswordUser = "$baseUrl/Master/reset_pass_user";
  static const String userQrCode = "$baseUrl/Master/user_qrcode";

  // Master customer
  static const String customerList = "$baseUrl/Master/customer_list";
  static const String deleteCustomer = "$baseUrl/Master/delete_customer";
  static const String resetPasswordCustomer =
      "$baseUrl/Master/reset_pass_customer";
  static const String customerListNoPaging =
      "$baseUrl/Master/customer_list_no_pagging";
  static const String getTimePerCustomer =
      "$baseUrl/Master/get_time_per_customer";
  static const String addCustomerSaldo =
      "$baseUrl/Master/add_customer_saldo";
  static const String syncCustomer = "$baseUrl/Master/sync_customer";

  // Master price
  static const String priceList = "$baseUrl/Master/price_list";
  static const String editPrice = "$baseUrl/Master/edit_price";

  // Master promo
  static const String promoList = "$baseUrl/Master/promo_list";
  static const String promoListNoPaging =
      "$baseUrl/Master/promo_list_no_pagging";
  static const String addPromo = "$baseUrl/Master/add_promo";
  static const String editPromo = "$baseUrl/Master/edit_promo";
  static const String deletePromo = "$baseUrl/Master/delete_promo";

  // Master category
  static const String categoryList = "$baseUrl/Master/category_list";
  static const String addCategory = "$baseUrl/Master/add_category";
  static const String editCategory = "$baseUrl/Master/edit_category";
  static const String deleteCategory = "$baseUrl/Master/delete_category";

  // Master unit
  static const String unitList = "$baseUrl/Master/unit_list";
  static const String addUnit = "$baseUrl/Master/add_unit";
  static const String editUnit = "$baseUrl/Master/edit_unit";
  static const String deleteUnit = "$baseUrl/Master/delete_unit";

  // Master product
  static const String productList = "$baseUrl/Master/product_list";
  static const String addProduct = "$baseUrl/Master/add_product";
  static const String editProduct = "$baseUrl/Master/edit_product";
  static const String deleteProduct = "$baseUrl/Master/delete_product";

  // Master payment
  static const String paymentList = "$baseUrl/Master/get_payment_list";

  // Master time save
  static const String checkTimeSave = "$baseUrl/Master/check_time_save";
  static const String getSaveCustomerTime =
      "$baseUrl/Master/get_save_customer_time";

  // Purchase
  static const String purchaseAdd = "$baseUrl/Purchase/purchase_add";
  static const String purchaseList = "$baseUrl/Purchase/purchase_list";
  static const String purchaseCancel = "$baseUrl/Purchase/purchase_cancel";
  static const String purchaseListProduct =
      "$baseUrl/Purchase/list_product_purchase";

  // Billing
  static const String tableList = "$baseUrl/Billing/get_table_list";
  static const String bookTable = "$baseUrl/Billing/book_table";
  static const String calculationPrice = "$baseUrl/Billing/calculation_price";
  static const String payment = "$baseUrl/Billing/payment";
  static const String moveTable = "$baseUrl/Billing/move_table";
  static const String addDuration = "$baseUrl/Billing/add_duration";
  static const String roundUpDuration = "$baseUrl/Billing/round_up_duration";
  static const String cancelTable = "$baseUrl/Billing/cancel_table";
  static const String transactionList = "$baseUrl/Billing/transaction_list";
  static const String transactionDetail = "$baseUrl/Billing/transaction_detail";
  static const String settingTable = "$baseUrl/Billing/setting_table";
  static const String updateSettingTable =
      "$baseUrl/Billing/update_setting_table";
  static const String resetLampu = "$baseUrl/Billing/reset_lampu";
  static const String timerExpired = "$baseUrl/Billing/timer_expired";
  static const String transactionSaldoList =
      "$baseUrl/Billing/transaction_saldo_list";

  // Cafe
  static const String saveTransactionCafe =
      "$baseUrl/Cafe/save_transaction_cafe";
  static const String keepTransactionCafe = "$baseUrl/Cafe/keep_transaction";
  static const String selectKeepTransactionCafe =
      "$baseUrl/Cafe/select_keep_transaction";
  static const String deleteKeepTransactionCafe =
      "$baseUrl/Cafe/delete_keep_transaction";
  static const String renameKeepTransactionCafe =
      "$baseUrl/Cafe/rename_keep_transaction";
  static const String transactionCafeList =
      "$baseUrl/Cafe/transaction_cafe_list";
  static const String transactionCafeDetail = "$baseUrl/Cafe/transaction_detail";
  static const String cancelTransactionCafe =
      "$baseUrl/Cafe/cancel_transaction_cafe";

  // Setting
  static const String pointExchangeList = "$baseUrl/Setting/point_exchange";
  static const String addPointExchange = "$baseUrl/Setting/add_point_exchange";
  static const String editPointExchange =
      "$baseUrl/Setting/edit_point_exchange";
  static const String deletePointExchange =
      "$baseUrl/Setting/delete_point_exchange";
  static const String categoryMejaList = "$baseUrl/Setting/category_meja";
  static const String addCategoryMeja = "$baseUrl/Setting/add_category_meja";
  static const String editCategoryMeja = "$baseUrl/Setting/edit_category_meja";
  static const String deleteCategoryMeja =
      "$baseUrl/Setting/delete_category_meja";
  static const String saldoList = "$baseUrl/Setting/saldo_list";
  static const String saldoNoPaging =
      "$baseUrl/Setting/saldo_list_no_pagging";
  static const String addSaldo = "$baseUrl/Setting/add_saldo";
  static const String editSaldo = "$baseUrl/Setting/edit_saldo";
  static const String deleteSaldo = "$baseUrl/Setting/delete_saldo";

  // Report
  static const String transactionTodayByCashier =
      "$baseUrl/Report/get_transaction_today_by_cashier";
  static const String billingReport = "$baseUrl/Report/billing_report";
  static const String cafeReport = "$baseUrl/Report/cafe_report";
  static const String saldoReport = "$baseUrl/Report/saldo_report";
  static const String stockReport = "$baseUrl/Report/stock";

  // Access (roles & menu permissions)
  static const String roleListNoPaging =
      "$baseUrl/Access/role_list_no_pagging";
  static const String addRole = "$baseUrl/Access/add_role";
  static const String menuListNoPaging =
      "$baseUrl/Access/menu_list_no_pagging";
  static const String roleAccess = "$baseUrl/Access/role_access";
  static const String updateRoleAccess = "$baseUrl/Access/update_role_access";
}
