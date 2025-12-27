import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bs.dart';
import 'app_localizations_en.dart';

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('bs'),
    Locale('en')
  ];

  String get appTitle;

  String get settingsTitle;

  String get languageLabel;

  String get english;

  String get bosnian;

  String get loyaltyTitle;

  String get loyaltyViewPoints;

  String get view;

  String get securityTitle;

  String get securitySubtitle;

  String get logout;

  String get wishlistTitle;

  String get wishlistLoggedOutTitle;

  String get wishlistLoggedOutSubtitle;

  String get wishlistCreateAccount;

  String get wishlistLoginAgain;

  String get wishlistLoadFailed;

  String get wishlistUpdateLogin;

  String get wishlistUpdateFailed;

  String get wishlistRemoved;

  String get wishlistNoFavouritesTitle;

  String get wishlistNoFavouritesSubtitle;

  String get createAccount;

  String get bookingsTitle;

  String get bookingsLoggedOutTitle;

  String get bookingsLoggedOutSubtitle;

  String get bookingsNoStays;

  String bookingsTotal(int total);

  String get bookingsTabCurrent;

  String get bookingsTabPast;

  String get bookingsTabCancelled;

  String get bookingsEmptyCurrentTitle;

  String get bookingsEmptyCurrentSubtitle;

  String get bookingsEmptyPastTitle;

  String get bookingsEmptyPastSubtitle;

  String get bookingsEmptyCancelledTitle;

  String get bookingsEmptyCancelledSubtitle;

  String get bookingsStatusUpcoming;

  String get bookingsStatusCompleted;

  String get bookingsStatusCancelled;

  String get bookingStatusCancelled;

  String get bookingsTotalPrice;

  String get bookingsLeaveReview;

  String get bookingsLoadFailed;

  String nightsLabel(int nights);

  String guestsLabel(int guests);

  String get landingLoadFailed;

  String get landingRecommendationsFailed;

  String get landingSnackSelectDates;

  String get landingSnackGuests;

  String get landingHeroTitle;

  String get landingHeroSubtitle;

  String get landingSearchHint;

  String get landingSelectDatesLabel;

  String get landingGuestsLabel;

  String get landingSearchButton;

  String get landingExploreTitle;

  String get landingExploreCaption;

  String get landingHotDealsTitle;

  String get landingHotDealsCaption;

  String get landingSeeAll;

  String get landingRecommendedTitle;

  String get landingRecommendedCaption;

  String get landingRecommendedEmpty;

  String get landingRecentTitle;

  String get landingRecentCaption;

  String get landingRecentLoadFailed;

  String get landingRecentBadge;

  String get landingThemeTitle;

  String get landingThemeCaption;

  String get landingQuickPicks;

  String get landingTagCTA;

  String get landingHotDealBadge;

  String get landingLimitedOffer;

  String landingFromPrice(String currency, String price);

  String get landingPerNight;

  String get landingForYouBadge;

  String get landingTagLoadFailed;

  String get landingTagNoHotels;

  String get reviewYourStay;

  String get retry;

  String get guestProfile;

  String get notifications;

  String get hotDealsTitle;

  String get hotDealsLoadFailed;

  String get hotDealsHeaderTitle;

  String get hotDealsHeaderEmptySubtitle;

  String hotDealsHeaderCount(int total);

  String hotDealsHeaderFiltered(int visible, int total);

  String get hotDealsSortLabel;

  String get hotDealsSortLowest;

  String get hotDealsSortHighest;

  String get hotDealsEmptyTitle;

  String get hotDealsEmptySubtitle;

  String get hotDealsFromLabel;

  String get notificationsHeaderTitle;

  String get notificationsAllCaughtUp;

  String notificationsUnreadCount(int unread);

  String get notificationsFilterAll;

  String get notificationsFilterUnread;

  String get notificationsMarkAllRead;

  String get notificationsLoggedOutTitle;

  String get notificationsLoggedOutSubtitle;

  String get notificationsLoginButton;

  String get notificationsEmptySubtitle;

  String get notificationsBadgeNew;

  String get notificationsPillReservation;

  String get notificationsPillCancelled;

  String get notificationsPillPayment;

  String get notificationsMessageReservationCreated;

  String get notificationsMessageReservationCancelled;

  String get notificationsMessagePaymentSucceeded;

  String get previewLoadFailed;

  String get previewSelectionTitle;

  String get previewContinue;

  String previewGuestsCount(int guests);

  String get previewSectionAbout;

  String get previewSectionFacilities;

  String get previewSectionAddOns;

  String get previewRoomsTitle;

  String get previewNoRooms;

  String get previewReviewsTitle;

  String get previewReviewsLoadFailed;

  String get previewReviewsEmpty;

  String get previewLoadMore;

  String previewReviewsCount(int count);

  String get previewHotelNotFound;

  String get previewHeaderFallback;

  String get previewWishlistAdded;

  String get previewNonSmoking;

  String previewRoomsLeftFew(int count);

  String previewRoomsLeft(int count);

  String get previewSelect;

  String get paymentTitle;

  String get paymentSecureStripe;

  String get paymentTotalToPay;

  String get paymentCardTitle;

  String get paymentCardSubtitle;

  String get paymentCardNameOptional;

  String get paymentCardInfo;

  String get paymentCardIncomplete;

  String get paymentTotalLabel;

  String get paymentContinue;

  String get paymentMethodCard;

  String get confirmTitle;

  String get confirmHeading;

  String get confirmSubheading;

  String get confirmStayDetails;

  String get confirmPaymentStatusPayAtProperty;

  String get confirmPaymentCompleted;

  String get confirmPaymentProcessing;

  String get confirmPaymentActionRequired;

  String confirmPaymentStatusGeneric(String status);

  String get confirmTotalPaid;

  String get confirmConfirmationNumber;

  String get confirmManageInfo;

  String get confirmBackHome;

  String get reservationLoginPrompt;

  String get reservationContinue;

  String get reservationStepStay;

  String get reservationStepAddOns;

  String get reservationStepPayment;

  String get reservationStepSummary;

  String reservationSleeps(int count);

  String get reservationSmoking;

  String get reservationAddOnsTitle;

  String get reservationAddOnsEmpty;

  String get reservationAddOnPerNight;

  String get reservationAddOnPerGuestPerNight;

  String get reservationAddOnPerStay;

  String get reservationPaymentMethodTitle;

  String get reservationPaymentCardDescription;

  String get reservationPaymentPayOnArrivalDescription;

  String reservationPriceSummaryTitle(String nights);

  String get reservationPriceRoom;

  String get reservationPriceAddOns;

  String get reservationPriceLoyalty;

  String get reservationPriceTotalApprox;

  String get reservationPriceNote;

  String reservationPhotosCount(int count);

  String get filtersTitle;

  String get filtersClearAll;

  String get filtersLoadWarning;

  String get filtersReset;

  String get filtersApply;

  String get filtersCityTitle;

  String get filtersCitySubtitle;

  String get filtersCityAny;

  String get filtersPriceTitle;

  String get filtersPriceSubtitle;

  String get filtersPriceMin;

  String get filtersPriceMax;

  String get filtersRatingTitle;

  String get filtersRatingSubtitle;

  String get filtersTripTitle;

  String get filtersTripSubtitle;

  String get filtersAddOnsSubtitle;

  String get filtersFacilitiesTitle;

  String get filtersFacilitiesSubtitle;

  String get searchFlexibleDates;

  String get searchTitle;

  String searchErrorCity(String city);

  String searchEmptyTitle(String city);

  String get searchEmptySubtitle;

  String searchCount(int count);

  String get searchPerNightTaxes;

  String get searchViewDetails;

  String get searchNoResultsTitle;

  String searchReviewsCount(int count);

  String get searchPerNightEstimate;

  String get searchRefine;

  String get previewYouWillPay;

  String get previewConfirmPay;

  String get previewConfirmReservation;

  String get previewStepReview;

  String get previewHeroTitle;

  String get previewPaymentCardPill;

  String get previewPaymentPayOnPropertyPill;

  String previewGuestsPill(int guests);

  String get previewCheckIn;

  String get previewCheckOut;

  String get previewPaymentCardTitle;

  String get previewPaymentPayOnPropertyTitle;

  String previewPaymentCardSubtitle(String total);

  String previewPaymentPayOnPropertySubtitle(String total);

  String get previewFinePrint;

  String get personalInfoTitle;

  String get personalInfoSubtitle;

  String get firstName;

  String get firstNameError;

  String get lastName;

  String get phoneOptional;

  String get saveChanges;

  String get currentPassword;

  String get currentPasswordError;

  String get newPassword;

  String get newPasswordError;

  String get confirmPassword;

  String get confirmPasswordError;

  String get changePassword;

  String get supportTitle;

  String get supportSubtitle;

  String get alreadyAccount;

  String get supportHeaderTitle;

  String get supportHeaderSubtitle;

  String get faqTitle;

  String get faqSubtitle;

  String get faqQ1;

  String get faqA1;

  String get faqQ2;

  String get faqA2;

  String get faqQ3;

  String get faqA3;

  String get faqQ4;

  String get faqA4;

  String get supportContactTitle;

  String get supportContactSubtitle;

  String get reviewRatingRequired;

  String get reviewMissingHotel;

  String get reviewSubmitted;

  String get reviewSubmitFailed;

  String reviewTitle(String hotelName);

  String get reviewSubtitle;

  String get reviewCommentLabel;

  String get reviewSubmit;

  String get navExplore;

  String get navBookings;

  String get navWishlist;

  String get navProfile;

  String get bookingDetailsTitle;

  String get bookingDetailsReservation;

  String get bookingDetailsGuests;

  String get bookingDetailsNights;

  String get bookingDetailsRoomType;

  String get bookingDetailsTotal;

  String get bookingDetailsReference;

  String get bookingDetailsReferenceHint;

  String get bookingCancelledTitle;

  String get bookingCancelledSummary;

  String get bookingCancelledOriginalTotal;

  String get bookingCancelledMessage;

  String get bookingCancelledChangedMind;

  String get bookingCancelledSearchAgain;

  String get bookingCurrentStayDetails;

  String get bookingCurrentStatusUpcoming;

  String get bookingCurrentToday;

  String bookingCurrentCountdown(String date, int days);

  String get bookingCurrentImportant;

  String get bookingCurrentImportantText;

  String get bookingCurrentChangePlans;

  String get bookingCurrentCancel;

  String get bookingPastTitle;

  String get bookingPastStaySummary;

  String get bookingPastTotalPaid;

  String get bookingPastStatusTitle;

  String get bookingPastStatusCompleted;

  String get bookingPastMessage;

  String get bookingPastTip;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['bs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  switch (locale.languageCode) {
    case 'bs': return AppLocalizationsBs();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale \"$locale\". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
