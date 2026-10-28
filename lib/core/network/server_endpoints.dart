/// تنها فهرست آدرس‌های سرور.
///
/// هیچ فایل دیگری اجازه ندارد مسیر API را به‌صورت رشته بنویسد؛ اگر روزی
/// مسیری روی سرور عوض شود، فقط همین فایل ویرایش می‌شود. مسیرها نسبی‌اند و
/// `ApiConfig.uri` پیشوند (`/api`) را خودش اضافه می‌کند.
class ServerEndpoints {
  ServerEndpoints._();

  // ==================== احراز هویت ====================
  static const String authLogin = '/auth/login/';
  static const String authLogout = '/auth/logout/';
  static const String authRegister = '/auth/register/';
  static const String authSendRegisterCode = '/auth/send-register-code/';
  static const String authRegisterPersonal = '/auth/register-personal/';
  static const String authChangePassword = '/auth/change-password/';
  static const String authPasswordReset = '/auth/password-reset/';
  static const String authPasswordResetConfirm =
      '/auth/password-reset/confirm/';

  // ==================== کاربر و برند ====================
  static const String userProfile = '/user/profile/';
  static const String gymBrand = '/gym-brand/';
  static const String coachInstructions = '/coach-instructions/';

  static String coachInstruction(int id) => '/coach-instructions/$id/';

  // ==================== ورزشکاران باشگاه ====================
  static const String clientAccess = '/client-access/';
  static const String clientProfile = '/client-profile/';
  static const String gymClients = '/gym-clients/';

  static String gymClient(int id) => '/gym-clients/$id/';

  static String gymClientAdjustTokens(int id) =>
      '/gym-clients/$id/adjust-tokens/';

  // ==================== توکن و پرداخت ====================
  static const String tokenPackages = '/token-packages/';
  static const String validateDiscountCode = '/validate-discount-code/';
  static const String purchaseToken = '/purchase-token/';
  static const String paymentCallback = '/payment-callback/';

  /// روش‌های پرداختی که همین حالا فعال‌اند (کارت‌به‌کارت / درگاه).
  ///
  /// کلاینت خودش تصمیم نمی‌گیرد چه چیزی نشان بدهد؛ این پاسخ تعیین می‌کند.
  static const String paymentMethods = '/payment-methods/';

  /// اطلاعات کارت مقصد برای پرداخت کارت‌به‌کارت.
  static const String paymentCard = '/payment-card/';
  static const String myPurchases = '/my-purchases/';

  /// بارگذاری رسید پرداخت یک سفارش.
  static String purchaseReceipt(int purchaseId) =>
      '/purchase-token/$purchaseId/receipt/';

  /// خواندن تصویر رسیدِ بارگذاری‌شده.
  static String purchaseReceiptFile(int purchaseId) =>
      '/purchase-token/$purchaseId/receipt/file/';

  // ==================== درخواست توکن ورزشکار ====================
  static const String tokenRequests = '/token-requests/';

  static String tokenRequestRespond(int id) => '/token-requests/$id/respond/';

  // ==================== تجهیزات و وعده‌ها ====================
  static const String equipmentCategories = '/equipment-categories/';
  static const String equipments = '/equipments/';
  static const String equipmentsBulkAdd = '/equipments/bulk-add/';
  static const String equipmentSuggestions = '/equipment-suggestions/';
  static const String meals = '/meals/';

  // ==================== ابزارهای حرفه‌ای مربی ====================
  // مسیرهای این بخش از قراردادهای فعال سرور گرفته شده‌اند. قابلیت‌هایی که
  // هنوز API ندارند عمداً رشتهٔ خالی‌اند تا لایهٔ سرویس هیچ درخواست حدسی
  // ارسال نکند.
  static const String exerciseLibrary = '/exercise-library/';
  static const String myExercises = '/exercise-library/mine/';
  static const String manualPrograms = '/programs/manual/';
  static const String manualProgramQuota = '/programs/manual/quota/';

  static const String coachTemplates = '';
  static const String nutritionAnalysis = '';
  static const String sectionDraftGeneration = '';

  static String myExercise(String externalId) =>
      '/exercise-library/mine/${Uri.encodeComponent(externalId)}/';

  static String manualProgram(int id) => '/programs/manual/$id/';

  static String programsHistoryForClient(int clientId) =>
      '$programsHistory?client_id=$clientId';

  static String equipment(int id) => '/equipments/$id/';

  static String equipmentCategory(int id) => '/equipment-categories/$id/';

  // ==================== برنامه‌ها ====================
  static const String programsGenerate = '/programs/generate/';
  static const String programsHistory = '/programs/history/';

  static String program(int id) => '/programs/$id/';

  static String programEdit(int id) => '/programs/$id/edit/';

  /// دانلود PDF کامل (ورزشی + غذایی).
  static String programPdf(int id) => '/programs/$id/pdf/';

  /// دانلود PDF فقط برنامه‌ی ورزشی.
  static String programPdfWorkout(int id) => '/programs/$id/pdf-workout/';

  /// دانلود PDF فقط برنامه‌ی غذایی.
  static String programPdfMeal(int id) => '/programs/$id/pdf-meal/';

  /// ساخت/فهرست کدهای یکبارمصرف دانلود یک برنامه (سمت مربی).
  static String programShareCode(int id) => '/programs/$id/share-code/';

  /// مصرف کد یکبارمصرف و گرفتن فایل (سمت ورزشکار، بدون نیاز به حساب).
  static const String programRedeemCode = '/programs/redeem-code/';

  // ==================== محتوای عمومی سایت ====================
  static const String homepage = '/homepage/';
  static const String contact = '/contact/';
  static const String teamMembers = '/team-members/';
  static const String features = '/features/';
  static const String blog = '/blog/';
}
