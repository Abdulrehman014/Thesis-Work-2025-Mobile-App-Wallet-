
class Api {
  static const String baseUrl = "https://wallet.demo.walt.id";


  static const loginPath = baseUrl + "/wallet-api/auth/login";
  static const registerPath = baseUrl + "/wallet-api/auth/register"
      "";
  static const retrieveWalletDetails = baseUrl + "/wallet-api/wallet/accounts/wallets";

  // static const acceptCredentials = baseUrl + "/wallet-api/wallet/$walletId/exchange/useOfferRequest";
  static const logOutPath = baseUrl + "/wallet-api/auth/logout";
}