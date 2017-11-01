/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/10/2017
 * Copyright :  S.Hamblett
 */

part of coap;

/// Event classes
class CoapRespondEvent {
  CoapResponse resp;

  CoapRespondEvent(this.resp);
}

class CoapRespondingEvent {
  CoapResponse resp;

  CoapRespondingEvent(this.resp);
}

class CoapReregisteringEvent {
  CoapRequest resp;

  CoapReregisteringEvent(this.resp);
}

/// This class describes the functionality of a CoAP Request as
/// a subclass of a CoAP Message. It provides:
/// 1. operations to answer a request by a response using respond()
/// 2. different ways to handle incoming responses: receiveResponse() or Response event
class CoapRequest extends CoapMessage {
  /// Initializes a request message.
  CoapRequest(int code) : this.isConfirmable(code, true);

  /// Initializes a request message.
  /// True if the request is Confirmable
  CoapRequest.isConfirmable(int code, bool confirmable)
      : super.withCode(
      confirmable ? CoapMessageType.con : CoapMessageType.non, code) {
    _method = code;
  }

  /// The request method(code)
  int _method;

  int get method => _method;

  /// Indicates whether this request is a multicast request or not.
  bool multicast;

  /// The URI of this CoAP message.
  Uri _uri;

  Uri get uri {
    if (_uri == null) {
      _uri = new Uri(
          scheme: CoapConstants.uriScheme,
          host: uriHost ?? "localhost",
          port: uriPort,
          path: uriPath,
          query: uriQuery);
    }
    return _uri;
  }

  set uri(Uri value) {
    if (value == null) {
      return;
    }
    final String host = value.host;
    int port = value.port;
    if ((host.isNotEmpty) &&
        (!CoapUtil.regIP.hasMatch(host)) &&
        (host != "localhost")) {
      uriHost = host;
    }
    if (port < 0) {
      if ((value.scheme.isNotEmpty) ||
          (value.scheme == CoapConstants.uriScheme)) {
        port = CoapConstants.defaultPort;
      } else if (value.scheme == CoapConstants.secureUriScheme) {
        port = CoapConstants.defaultSecurePort;
      }
    }
    if (uriPort != port) {
      if (port != CoapConstants.defaultPort) {
        uriPort = port;
      } else {
        uriPort = 0;
      }
    }
    uriPath = value.path;
    uriQuery = value.query;
    InternetAddress.lookup(host)
      ..then((List<InternetAddress> addresses) {
        destination = addresses.isNotEmpty ? addresses[0] : null;
        _uri = value;
      });
  }

  /// The response to this request.
  CoapResponse _currentResponse;

  CoapResponse get response => _currentResponse;

  set response(CoapResponse value) {
    _currentResponse = value;
    emitEvent(new CoapRespondEvent(value));
    // Add to the internal response stream
    _responseStream.add(value);
  }

  /// The endpoint for this request
  CoapIEndPoint endPoint;

  /// Uri
  CoapRequest setUri(String value) {
    String tmp = value;
    if (!value.startsWith("coap://") && !value.startsWith("coaps://"))
      tmp = "coap://" + value;
    uri = new Uri.dataFromString(tmp);
    return this;
  }

  /// Sets CoAP's observe option. If the target resource of this request
  /// responds with a success code and also sets the observe option, it will
  /// send more responses in the future whenever the resource's state changes.
  CoapRequest markObserve() {
    observe = 0;
    return this;
  }

  /// Sets CoAP's observe option to the value of 1 to proactively cancel.
  CoapRequest markObserveCancel() {
    observe = 1;
    return this;
  }

  /// Gets the value of a query parameter as a String,
  /// or null if the parameter does not exist.
  String getParameter(String name) {
    for (CoapOption query in getOptions(optionTypeUriQuery)) {
      final String val = query.stringValue;
      if (val.isEmpty) {
        continue;
      }
      if (val.startsWith(name + "=")) return val.substring(name.length + 1);
    }
    return null;
  }

  /// Sends this message.
  CoapRequest send() {
    _validateBeforeSending();
    endPoint.sendRequest(this);
    // Clear the internal response stream
    _responseStream.stream.drain();
    return this;
  }

  void _validateBeforeSending() {
    if (destination == null)
      throw new StateError(
          "CoapRequest::validateBeforeSending - Missing destination");
  }

  /// Response stream, used by waitForResponse
  StreamController<CoapResponse> _responseStream =
  new StreamController<CoapResponse>();

  /// Wait for a response.
  /// Returns the response, or null if timeout occured.
  FutureOr<CoapResponse> waitForResponse(int millisecondsTimeout) {
    final Completer<CoapResponse> completer = new Completer<CoapResponse>();
    if ((_currentResponse == null) &&
        (!isCancelled) &&
        (!isTimedOut) &&
        (!isRejected)) {
      final sleepFuture = CoapUtil.asyncSleep(millisecondsTimeout);
      final responseFuture =
      _responseStream.stream.listen((CoapResponse resp) {});
      Future.any<CoapResponse>([sleepFuture, responseFuture.asFuture()])
        ..then((CoapResponse resp) {
          _currentResponse = response;
          responseFuture.cancel();
          return completer.complete(response);
        });
      return completer.future;
    }
    return _currentResponse;
  }

  /// Fire the respond event
  void fireRespond(CoapResponse response) {
    emitEvent(new CoapRespondEvent(response));
  }

  /// Fire the responding event
  void fireResponding(CoapResponse response) {
    emitEvent(new CoapRespondingEvent(response));
  }

  /// Fire the reregistering event
  void fireReregistering(CoapRequest request) {
    emitEvent(new CoapReregisteringEvent(request));
  }

  /// Construct a GET request.
  static CoapRequest newGet() {
    return new CoapRequest(CoapCode.methodGET);
  }

  /// Construct a POST request.
  static CoapRequest newPost() {
    return new CoapRequest(CoapCode.methodPOST);
  }

  /// Construct a PUT request.
  static CoapRequest newPut() {
    return new CoapRequest(CoapCode.methodPUT);
  }

  /// Construct a DELETE request.
  static CoapRequest newDelete() {
    return new CoapRequest(CoapCode.methodDELETE);
  }
}