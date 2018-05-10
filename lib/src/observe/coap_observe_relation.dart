/*
 * Package : Coap
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/10/2017
 * Copyright :  S.Hamblett
 */

part of coap;

/// Represents a relation between a client endpoint and a resource on this server.
class CoapObserveRelation {
  /// Constructs a new observe relation.
  /// The observing endpoint
  /// The observed resource
  /// The exchange that tries to establish the observe relation
  CoapObserveRelation(CoapObservingEndpoint endpoint, CoapIResource resource,
      CoapExchange exchange) {
    if (endpoint == null)
      throw new ArgumentError.notNull("CoapObserveRelation::endpoint");
    if (resource == null)
      throw new ArgumentError.notNull("CoapObserveRelation::resource");
    if (exchange == null)
      throw new ArgumentError.notNull("CoapObserveRelation::exchange");
    _endpoint = endpoint;
    _resource = resource;
    _exchange = exchange;
    _key = "$source#${exchange.request.tokenString}";
  }

  CoapILogger log = new CoapLogManager('console').logger;
  CoapConfig _config;
  CoapObservingEndpoint _endpoint;

  /// Source endpoint of the observing endpoint
  InternetAddress get source => _endpoint.endpoint;
  CoapIResource _resource;

  CoapIResource get resource => _resource;
  CoapExchange _exchange;

  CoapExchange get exchange => _exchange;
  CoapResponse currentControlNotification;
  CoapResponse nextControlNotification;
  String _key;
  String get key => _key;

  /// A value indicating if this relation has been established
  bool established;
  DateTime _interestCheckTime = new DateTime.now();
  int _interestCheckCounter = 1;

  /// The notifications that have been sent, so they can be removed from the Matcher
  Queue<CoapResponse> _notifications = new Queue<CoapResponse>();

  /// Cancel this observe relation.
  void cancel() {
    log.debug(
        "CoapObserveRelation::Cancel observe relation from $_key with ${_resource
            .path}");
    // Stop ongoing retransmissions
    if (_exchange.response != null) {
      _exchange.response.cancel();
    }
    established = false;
    _resource.removeObserveRelation(this);
    _endpoint.removeObserveRelation(this);
    _exchange.complete = true;
  }

  /// Cancel all observer relations that this server has
  /// established with this's realtion's endpoint.
  void cancelAll() {
    _endpoint.cancelAll();
  }

  /// Notifies the observing endpoint that the resource has been changed.
  void notifyObservers() {
    // Makes the resource process the same request again
    _resource.handleRequest(_exchange);
  }

  bool check() {
    bool check = false;
    final DateTime now = new DateTime.now();
    check = check ||
        _interestCheckTime
            .add(new Duration(
            milliseconds: CoapConfig.inst.notificationCheckIntervalTime))
            .isBefore(now);
    check = check ||
        (++_interestCheckCounter >=
            CoapConfig.inst.notificationCheckIntervalCount);
    if (check) {
      _interestCheckTime = now;
      _interestCheckCounter = 0;
    }
    return check;
  }

  void addNotification(CoapResponse notification) {
    _notifications.add(notification);
  }

  Iterable<CoapResponse> clearNotifications() {
    Iterable<CoapResponse> list;
    list = _notifications.toList();
    _notifications.clear();
    return list;
  }
}