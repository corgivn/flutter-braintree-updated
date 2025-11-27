import 'dart:async';

import 'package:flutter/services.dart';

import 'request.dart';
import 'result.dart';

class BraintreeDropIn {
  static const MethodChannel _kChannel =
      const MethodChannel('flutter_braintree.drop_in');

  const BraintreeDropIn._();

  /// Launches the Braintree Drop-in UI.
  ///
  /// The required options can be placed inside the [request] object.
  /// See its documentation for more information.
  ///
  /// Returns a Future that resolves to a [BraintreeDropInResult] containing
  /// all the relevant information, or `null` if the selection was canceled.
  static Future<BraintreeDropInResult?> start(
      BraintreeDropInRequest request) async {
    var result = await _kChannel.invokeMethod(
      'start',
      request.toJson(),
    );
    if (result == null) return null;
    return BraintreeDropInResult.fromJson(result);
  }

  /// Sets the preferred language for the native iOS side by updating the
  /// `AppleLanguages` UserDefaults key.
  static Future<void> setLanguage(String language) async {
    await _kChannel.invokeMethod(
      'setLanguage',
      <String, dynamic>{
        'language': language,
      },
    );
  }
}
