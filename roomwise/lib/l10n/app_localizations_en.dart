// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Roomwise';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get english => 'English';

  @override
  String get bosnian => 'Bosnian';

  @override
  String get loyaltyTitle => 'Loyalty';

  @override
  String get loyaltyViewPoints => 'View your points';

  @override
  String get view => 'View';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle => 'Update your password regularly to keep your account safe.';

  @override
  String get logout => 'Log out';

  @override
  String get wishlistTitle => 'Wishlist';

  @override
  String get wishlistLoggedOutTitle => 'Save your favourite stays';

  @override
  String get wishlistLoggedOutSubtitle => 'Create an account or log in to start building your wishlist and quickly find places you love.';

  @override
  String get wishlistCreateAccount => 'Create account';

  @override
  String get wishlistLoginAgain => 'Please log in again to view your wishlist.';

  @override
  String get wishlistLoadFailed => 'Failed to load wishlist.';

  @override
  String get wishlistUpdateLogin => 'Please log in to update wishlist.';

  @override
  String get wishlistUpdateFailed => 'Failed to update wishlist.';

  @override
  String get wishlistRemoved => 'Removed from wishlist';

  @override
  String get wishlistNoFavouritesTitle => 'No favourites yet';

  @override
  String get wishlistNoFavouritesSubtitle => 'Tap the heart on a hotel to add it to your wishlist and easily revisit it later.';

  @override
  String get reviewYourStay => 'Review your stay';

  @override
  String get retry => 'Retry';

  @override
  String get guestProfile => 'Guest profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get personalInfoTitle => 'Personal information';

  @override
  String get personalInfoSubtitle => 'Edit your basic details used for bookings and communication.';

  @override
  String get firstName => 'First name';

  @override
  String get firstNameError => 'Please enter your first name.';

  @override
  String get lastName => 'Last name';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get currentPassword => 'Current password';

  @override
  String get currentPasswordError => 'Please enter your current password.';

  @override
  String get newPassword => 'New password';

  @override
  String get newPasswordError => 'Password should be at least 6 characters.';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get confirmPasswordError => 'Passwords do not match.';

  @override
  String get changePassword => 'Change password';

  @override
  String get supportTitle => 'Support & FAQ';

  @override
  String get supportSubtitle => 'Find answers and contact our support team.';

  @override
  String get alreadyAccount => 'I already have an account';

  @override
  String get supportHeaderTitle => 'How can we help?';

  @override
  String get supportHeaderSubtitle => 'Browse common questions or reach out to our support team if something is unclear.';

  @override
  String get faqTitle => 'Frequently asked questions';

  @override
  String get faqSubtitle => 'Tap a question to see more details.';

  @override
  String get faqQ1 => 'How do I change or cancel my reservation?';

  @override
  String get faqA1 => 'You can manage your stays from the Bookings tab. Tap on a reservation to view details and see the available options.';

  @override
  String get faqQ2 => 'Where can I see my loyalty points?';

  @override
  String get faqA2 => 'Your current point balance is visible in the Profile section under “Loyalty points”.';

  @override
  String get faqQ3 => 'What payment methods are supported?';

  @override
  String get faqA3 => 'You can usually pay by card via Stripe. Availability of other methods depends on the hotel and your country.';

  @override
  String get faqQ4 => 'I found an issue with my booking. What should I do?';

  @override
  String get faqA4 => 'If something looks wrong, please contact our support team with your booking reference so we can help as soon as possible.';

  @override
  String get supportContactTitle => 'Contact support';

  @override
  String get supportContactSubtitle => 'Didn’t find what you were looking for? Reach out and we’ll get back to you as soon as possible.';

  @override
  String get navExplore => 'Explore';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navWishlist => 'Wishlist';

  @override
  String get navProfile => 'Profile';

  @override
  String get bookingDetailsTitle => 'Booking details';

  @override
  String get bookingDetailsReservation => 'Reservation details';

  @override
  String get bookingDetailsGuests => 'Guests';

  @override
  String get bookingDetailsNights => 'Nights';

  @override
  String get bookingDetailsRoomType => 'Room type';

  @override
  String get bookingDetailsTotal => 'Total amount';

  @override
  String get bookingDetailsReference => 'Reference';

  @override
  String get bookingDetailsReferenceHint =>
      'Use this confirmation number if the property requests it.';

  @override
  String get bookingCancelledTitle => 'Cancelled reservation';

  @override
  String get bookingCancelledSummary => 'Reservation summary';

  @override
  String get bookingCancelledOriginalTotal => 'Original total';

  @override
  String get bookingCancelledMessage =>
      'This reservation was cancelled. Refunds or charges depend on the property’s cancellation policy and the time of cancellation.';

  @override
  String get bookingCancelledChangedMind => 'Changed your mind?';

  @override
  String get bookingCancelledSearchAgain => 'Search this hotel again';

  @override
  String get bookingCurrentStayDetails => 'Stay details';

  @override
  String get bookingCurrentStatusUpcoming => 'Upcoming stay';

  @override
  String get bookingCurrentToday =>
      'Check-in is today. Have a great stay!';

  @override
  String bookingCurrentCountdown(String date, int days) =>
      'You will check-in on $date ($days day${days == 1 ? '' : 's'} left).';

  @override
  String get bookingCurrentImportant => 'Important info';

  @override
  String get bookingCurrentImportantText =>
      'Check the property’s cancellation policy before cancelling. Some stays may be non-refundable or only partially refundable depending on how close you are to check-in.';

  @override
  String get bookingCurrentChangePlans => 'Need to change plans?';

  @override
  String get bookingCurrentCancel => 'Cancel reservation';

  @override
  String get bookingPastTitle => 'Past stay';

  @override
  String get bookingPastStaySummary => 'Stay summary';

  @override
  String get bookingPastTotalPaid => 'Total paid';

  @override
  String get bookingPastStatusTitle => 'Status';

  @override
  String get bookingPastStatusCompleted => 'Completed stay';

  @override
  String get bookingPastMessage =>
      'We hope you enjoyed your trip. Your past stays help you remember where you’ve been – and make it easier to book again.';

  @override
  String get bookingPastTip =>
      'Tip: You can rate this stay from your Trips list to help other guests.';

  @override
  String get createAccount => 'Create account';

  @override
  String get bookingsTitle => 'Your trips';

  @override
  String get bookingsLoggedOutTitle => 'Keep all your trips in one place';

  @override
  String get bookingsLoggedOutSubtitle =>
      'Create an account or log in to see your upcoming stays, history and cancellations.';

  @override
  String get bookingsNoStays => 'No stays yet – start exploring!';

  @override
  String bookingsTotal(int total) =>
      '$total total booking${total == 1 ? '' : 's'}';

  @override
  String get bookingsTabCurrent => 'Current';

  @override
  String get bookingsTabPast => 'Past';

  @override
  String get bookingsTabCancelled => 'Cancelled';

  @override
  String get bookingsEmptyCurrentTitle => 'No upcoming stays';

  @override
  String get bookingsEmptyCurrentSubtitle =>
      'Once you book your next trip, it will appear here.';

  @override
  String get bookingsEmptyPastTitle => 'No past stays yet';

  @override
  String get bookingsEmptyPastSubtitle =>
      'After your trips finish, you will see them here.';

  @override
  String get bookingsEmptyCancelledTitle => 'No cancelled stays';

  @override
  String get bookingsEmptyCancelledSubtitle =>
      'Stays you cancel will appear here for reference.';

  @override
  String get bookingsStatusUpcoming => 'Upcoming';

  @override
  String get bookingsStatusCompleted => 'Completed';

  @override
  String get bookingsStatusCancelled => 'Cancelled';

  @override
  String get bookingStatusCancelled => 'Cancelled';

  @override
  String get bookingsTotalPrice => 'Total price';

  @override
  String get bookingsLeaveReview => 'Leave a review';

  @override
  String get bookingsLoadFailed => 'Failed to load your bookings.';

  @override
  String nightsLabel(int nights) => nights == 1 ? 'night' : 'nights';

  @override
  String guestsLabel(int guests) => guests == 1 ? 'guest' : 'guests';

  @override
  String get notificationsHeaderTitle => 'Your updates';

  @override
  String get notificationsAllCaughtUp => "You're all caught up.";

  @override
  String notificationsUnreadCount(int unread) =>
      '$unread unread notification${unread == 1 ? '' : 's'}.';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterUnread => 'Unread';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsLoggedOutTitle =>
      'Log in to see your notifications';

  @override
  String get notificationsLoggedOutSubtitle =>
      "We'll show updates about your reservations, payments and account here.";

  @override
  String get notificationsLoginButton => 'Log in';

  @override
  String get notificationsEmptySubtitle =>
      "We'll let you know when there's something new about your stays.";

  @override
  String get notificationsBadgeNew => 'New';

  @override
  String get notificationsPillReservation => 'Reservation';

  @override
  String get notificationsPillCancelled => 'Cancelled';

  @override
  String get notificationsPillPayment => 'Payment';

  @override
  String get notificationsMessageReservationCreated =>
      'Your reservation has been created.';

  @override
  String get notificationsMessageReservationCancelled =>
      'Your reservation was cancelled.';

  @override
  String get notificationsMessagePaymentSucceeded =>
      'Payment completed successfully.';

  @override
  String get hotDealsTitle => 'Hot deals';

  @override
  String get hotDealsLoadFailed => 'Failed to load hot deals.';

  @override
  String get hotDealsHeaderTitle => "Today's hot deals";

  @override
  String get hotDealsHeaderEmptySubtitle =>
      "We'll show limited time offers here.";

  @override
  String hotDealsHeaderCount(int total) =>
      '$total deals available right now.';

  @override
  String hotDealsHeaderFiltered(int visible, int total) =>
      '$visible of $total deals match your filters.';

  @override
  String get hotDealsSortLabel => 'Sort by';

  @override
  String get hotDealsSortLowest => 'Lowest price';

  @override
  String get hotDealsSortHighest => 'Highest price';

  @override
  String get hotDealsEmptyTitle => 'No hot deals found';

  @override
  String get hotDealsEmptySubtitle =>
      'Try changing your search text or sort order to see more options.';

  @override
  String get hotDealsFromLabel => 'From';

  @override
  String get previewLoadFailed => 'Failed to load hotel details.';

  @override
  String get previewSelectionTitle => 'Choose dates & guests';

  @override
  String get previewContinue => 'Continue';

  @override
  String previewGuestsCount(int guests) =>
      guests == 1 ? '1 guest' : '$guests guests';

  @override
  String get previewSectionAbout => 'About this stay';

  @override
  String get previewSectionFacilities => 'Facilities';

  @override
  String get previewSectionAddOns => 'Add-ons';

  @override
  String get previewRoomsTitle => 'Rooms';

  @override
  String get previewNoRooms => 'No rooms available for the selected dates.';

  @override
  String get previewReviewsTitle => 'Reviews';

  @override
  String get previewReviewsLoadFailed => 'Failed to load reviews.';

  @override
  String get previewReviewsEmpty => 'No reviews yet.';

  @override
  String get previewLoadMore => 'Load more';

  @override
  String previewReviewsCount(int count) =>
      count == 1 ? '1 review' : '$count reviews';

  @override
  String get previewHotelNotFound => 'Hotel not found.';

  @override
  String get previewHeaderFallback => 'Hotel';

  @override
  String get previewWishlistAdded => 'Added to wishlist';

  @override
  String get previewNonSmoking => 'Non-smoking';

  @override
  String previewRoomsLeftFew(int count) => 'Only $count left!';

  @override
  String previewRoomsLeft(int count) => '$count rooms left';

  @override
  String get previewSelect => 'Select';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentSecureStripe => 'Secure payment with Stripe';

  @override
  String get paymentTotalToPay => 'Total to pay';

  @override
  String get paymentCardTitle => 'Card details';

  @override
  String get paymentCardSubtitle =>
      "We won't charge your card until you confirm on the next step.";

  @override
  String get paymentCardNameOptional => 'Name on card (optional)';

  @override
  String get paymentCardInfo =>
      'Your card details are processed securely by Stripe. RoomWise never stores full card numbers.';

  @override
  String get paymentCardIncomplete => 'Please enter complete card details.';

  @override
  String get paymentTotalLabel => 'Total';

  @override
  String get paymentContinue => 'Continue to preview';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get confirmTitle => 'Reservation confirmed';

  @override
  String get confirmHeading => 'Your booking is confirmed!';

  @override
  String get confirmSubheading =>
      "We’ve sent your confirmation to your email.";

  @override
  String get confirmStayDetails => 'Stay details';

  @override
  String get confirmPaymentStatusPayAtProperty => 'Pay at property';

  @override
  String get confirmPaymentCompleted => 'Payment completed';

  @override
  String get confirmPaymentProcessing => 'Payment processing';

  @override
  String get confirmPaymentActionRequired => 'Action required';

  @override
  String confirmPaymentStatusGeneric(String status) =>
      'Payment: $status';

  @override
  String get confirmTotalPaid => 'Total paid';

  @override
  String get confirmConfirmationNumber => 'Confirmation number';

  @override
  String get confirmManageInfo =>
      'You can view or manage this reservation from your bookings at any time.';

  @override
  String get confirmBackHome => 'Back to home';

  @override
  String get reservationLoginPrompt => 'Please log in to reserve a room.';

  @override
  String get reservationContinue => 'Continue';

  @override
  String get reservationStepStay => 'Stay';

  @override
  String get reservationStepAddOns => 'Add-ons';

  @override
  String get reservationStepPayment => 'Payment';

  @override
  String get reservationStepSummary => 'Summary';

  @override
  String reservationSleeps(int count) => 'Sleeps $count';

  @override
  String get reservationSmoking => 'Smoking';

  @override
  String get reservationAddOnsTitle => 'Add-ons';

  @override
  String get reservationAddOnsEmpty =>
      'No add-ons available for this stay.';

  @override
  String get reservationAddOnPerNight => 'Per night';

  @override
  String get reservationAddOnPerGuestPerNight => 'Per guest per night';

  @override
  String get reservationAddOnPerStay => 'Per stay';

  @override
  String get reservationPaymentMethodTitle => 'Payment method';

  @override
  String get reservationPaymentCardDescription => 'Pay now with card';

  @override
  String get reservationPaymentPayOnArrivalDescription => 'Pay on arrival';

  @override
  String reservationPriceSummaryTitle(String nights) =>
      'Price summary ($nights)';

  @override
  String get reservationPriceRoom => 'Room';

  @override
  String get reservationPriceAddOns => 'Add-ons';

  @override
  String get reservationPriceLoyalty => 'Loyalty discount';

  @override
  String get reservationPriceTotalApprox => 'Total (approx.)';

  @override
  String get reservationPriceNote =>
      'Final price may vary slightly depending on currency and fees.';

  @override
  String reservationPhotosCount(int count) =>
      '$count photo${count == 1 ? '' : 's'}';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersClearAll => 'Clear all';

  @override
  String get filtersLoadWarning =>
      'Some filters could not load. Showing available options.';

  @override
  String get filtersReset => 'Reset';

  @override
  String get filtersApply => 'Apply';

  @override
  String get filtersCityTitle => 'City';

  @override
  String get filtersCitySubtitle => 'Choose where you want to stay';

  @override
  String get filtersCityAny => 'Any city';

  @override
  String get filtersPriceTitle => 'Price per night';

  @override
  String get filtersPriceSubtitle => 'Set your preferred budget range';

  @override
  String get filtersPriceMin => 'Min';

  @override
  String get filtersPriceMax => 'Max';

  @override
  String get filtersRatingTitle => 'Minimum rating';

  @override
  String get filtersRatingSubtitle =>
      'See only hotels above a certain score';

  @override
  String get filtersTripTitle => 'Trip details';

  @override
  String get filtersTripSubtitle =>
      'Choose your dates and number of guests';

  @override
  String get filtersAddOnsSubtitle => 'Enhance your stay with extras';

  @override
  String get filtersFacilitiesTitle => 'Facilities';

  @override
  String get filtersFacilitiesSubtitle => 'Pick what matters most to you';

  @override
  String get searchFlexibleDates => 'Flexible dates';

  @override
  String get searchTitle => 'Search stays';

  @override
  String searchErrorCity(String city) =>
      'Failed to load hotels for $city.';

  @override
  String searchEmptyTitle(String city) => 'No stays found in $city.';

  @override
  String get searchEmptySubtitle =>
      'Try adjusting your dates or filters.';

  @override
  String searchCount(int count) =>
      '$count stay${count == 1 ? '' : 's'}';

  @override
  String get searchPerNightTaxes =>
      'per night · incl. taxes (est.)';

  @override
  String get searchViewDetails => 'View details';

  @override
  String get searchNoResultsTitle =>
      'No stays match your search. Try adjusting filters or dates.';

  @override
  String searchReviewsCount(int count) =>
      '$count review${count == 1 ? '' : 's'}';

  @override
  String get searchPerNightEstimate => 'per night · est.';

  @override
  String get searchRefine => 'Refine';

  @override
  String get previewYouWillPay => 'You will pay';

  @override
  String get previewConfirmPay => 'Confirm & pay';

  @override
  String get previewConfirmReservation => 'Confirm reservation';

  @override
  String get previewStepReview => 'Review';

  @override
  String get previewHeroTitle => 'One last look before you go';

  @override
  String get previewPaymentCardPill => 'Card payment';

  @override
  String get previewPaymentPayOnPropertyPill => 'Pay at property';

  @override
  String previewGuestsPill(int guests) => 'Guests: $guests';

  @override
  String get previewCheckIn => 'Check-in';

  @override
  String get previewCheckOut => 'Check-out';

  @override
  String get previewPaymentCardTitle => 'Card (online via Stripe)';

  @override
  String get previewPaymentPayOnPropertyTitle => 'Pay at property';

  @override
  String previewPaymentCardSubtitle(String total) =>
      "We'll securely process $total with your card.";

  @override
  String previewPaymentPayOnPropertySubtitle(String total) =>
      "You'll pay $total directly at the property when you arrive.";

  @override
  String get previewFinePrint =>
      "By confirming, you agree to the property’s cancellation policy and RoomWise terms of service.";

  @override
  String get landingLoadFailed => 'Failed to load data. Please try again.';

  @override
  String get landingRecommendationsFailed =>
      'Could not load recommendations.';

  @override
  String get landingSnackSelectDates => 'Please select dates first.';

  @override
  String get landingSnackGuests => 'Please set number of guests.';

  @override
  String get landingHeroTitle => 'Find your next stay';

  @override
  String get landingHeroSubtitle =>
      'Smart search for hotels across Bosnia & Herzegovina.';

  @override
  String get landingSearchHint => 'Search by hotel or city';

  @override
  String get landingSelectDatesLabel => 'Select dates';

  @override
  String get landingGuestsLabel => 'Guests';

  @override
  String get landingSearchButton => 'Search stays';

  @override
  String get landingExploreTitle => 'Explore places';

  @override
  String get landingExploreCaption =>
      'Popular cities other guests are booking.';

  @override
  String get landingHotDealsTitle => 'Hot deals';

  @override
  String get landingHotDealsCaption =>
      'Limited-time discounts from top stays.';

  @override
  String get landingSeeAll => 'See all';

  @override
  String get landingRecommendedTitle => 'Recommended for you';

  @override
  String get landingRecommendedCaption =>
      'Based on your wishlist and bookings.';

  @override
  String get landingRecommendedEmpty =>
      'No picks yet. Try searching to get suggestions.';

  @override
  String get landingThemeTitle => 'Theme hotels';

  @override
  String get landingThemeCaption =>
      'Pick by vibe: business, spa, romantic...';

  @override
  String get landingQuickPicks => 'Quick picks';

  @override
  String get landingTagCTA => 'Tap to view hotels';

  @override
  String get landingHotDealBadge => 'Hot deal';

  @override
  String get landingLimitedOffer => 'Limited offer';

  @override
  String landingFromPrice(String currency, String price) =>
      'From $currency $price';

  @override
  String get landingPerNight => 'per night';

  @override
  String get landingForYouBadge => 'For you';

  @override
  String get landingTagLoadFailed =>
      'Failed to load hotels for this category.';

  @override
  String get landingTagNoHotels =>
      'No hotels found for this category.';

  @override
  String get reviewRatingRequired => 'Please choose a rating.';

  @override
  String get reviewMissingHotel =>
      'Hotel information is missing for this booking.';

  @override
  String get reviewSubmitted => 'Review submitted. Thank you!';

  @override
  String get reviewSubmitFailed =>
      'Failed to submit review. Please try again.';

  @override
  String reviewTitle(String hotelName) =>
      'Rate your stay at $hotelName';

  @override
  String get reviewSubtitle =>
      'Your feedback helps other guests and the hotel improve.';

  @override
  String get reviewCommentLabel => 'Tell us more (optional)';

  @override
  String get reviewSubmit => 'Submit review';
}
