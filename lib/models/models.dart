class DashboardStats {
  const DashboardStats({
    this.totalLogs = 0,
    this.sentCards = 0,
    this.receivedCards = 0,
    this.pendingOut = 0,
    this.pendingIn = 0,
    this.outStock = 0,
    this.inStock = 0,
  });

  final int totalLogs;
  final int sentCards;
  final int receivedCards;
  final int pendingOut;
  final int pendingIn;
  final int outStock;
  final int inStock;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalLogs: _asInt(json['total_logs']),
        sentCards: _asInt(json['sent_cards']),
        receivedCards: _asInt(json['received_cards']),
        pendingOut: _asInt(json['pending_out']),
        pendingIn: _asInt(json['pending_in']),
        outStock: _asInt(json['out_stock']),
        inStock: _asInt(json['in_stock']),
      );
}

class QsoLog {
  const QsoLog({
    required this.id,
    this.myCallsign = '',
    this.stationCallsign = '',
    this.qsoDate = '',
    this.timeOn = '',
    this.timeOff = '',
    this.freq,
    this.freqRx,
    this.band = '',
    this.bandRx = '',
    this.mode = '',
    this.submode = '',
    this.rstSent = '',
    this.rstRcvd = '',
    this.qslSent = '',
    this.qslRcvd = '',
    this.qslSentDate = '',
    this.qslRcvdDate = '',
    this.myGridsquare = '',
    this.gridsquare = '',
    this.comment = '',
    this.notes = '',
    this.satName = '',
    this.satMode = '',
    this.propMode = '',
    this.repeaterCallsign = '',
    this.repeaterLocation = '',
    this.uplinkFreq,
    this.downlinkFreq,
    this.txPwr,
    this.createdAt = '',
    this.updatedAt = '',
    this.qslCards = const [],
    this.raw = const {},
  });

  final int id;
  final String myCallsign;
  final String stationCallsign;
  final String qsoDate;
  final String timeOn;
  final String timeOff;
  final double? freq;
  final double? freqRx;
  final String band;
  final String bandRx;
  final String mode;
  final String submode;
  final String rstSent;
  final String rstRcvd;
  final String qslSent;
  final String qslRcvd;
  final String qslSentDate;
  final String qslRcvdDate;
  final String myGridsquare;
  final String gridsquare;
  final String comment;
  final String notes;
  final String satName;
  final String satMode;
  final String propMode;
  final String repeaterCallsign;
  final String repeaterLocation;
  final double? uplinkFreq;
  final double? downlinkFreq;
  final double? txPwr;
  final String createdAt;
  final String updatedAt;
  final List<QslCard> qslCards;
  final Map<String, dynamic> raw;

  factory QsoLog.fromJson(Map<String, dynamic> json) => QsoLog(
        id: _asInt(json['id']),
        myCallsign: _asString(json['my_callsign']),
        stationCallsign: _asString(json['station_callsign']),
        qsoDate: _asString(json['qso_date']),
        timeOn: _asString(json['time_on']),
        timeOff: _asString(json['time_off']),
        freq: _asDouble(json['freq']),
        freqRx: _asDouble(json['freq_rx']),
        band: _asString(json['band']),
        bandRx: _asString(json['band_rx']),
        mode: _asString(json['mode']),
        submode: _asString(json['submode']),
        rstSent: _asString(json['rst_sent']),
        rstRcvd: _asString(json['rst_rcvd']),
        qslSent: _asString(json['qsl_sent']),
        qslRcvd: _asString(json['qsl_rcvd']),
        qslSentDate: _asString(json['qsl_sent_date']),
        qslRcvdDate: _asString(json['qsl_rcvd_date']),
        myGridsquare: _asString(json['my_gridsquare']),
        gridsquare: _asString(json['gridsquare']),
        comment: _asString(json['comment']),
        notes: _asString(json['notes']),
        satName: _asString(json['sat_name']),
        satMode: _asString(json['sat_mode']),
        propMode: _asString(json['prop_mode']),
        repeaterCallsign: _asString(json['repeater_callsign']),
        repeaterLocation: _asString(json['repeater_location']),
        uplinkFreq: _asDouble(json['uplink_freq']),
        downlinkFreq: _asDouble(json['downlink_freq']),
        txPwr: _asDouble(json['tx_pwr']),
        createdAt: _asString(json['created_at']),
        updatedAt: _asString(json['updated_at']),
        qslCards: _asMapList(json['qsl_cards']).map(QslCard.fromJson).toList(growable: false),
        raw: Map<String, dynamic>.from(json),
      );

  Map<String, dynamic> get editablePayload => {
        'station_callsign': stationCallsign,
        'qso_date': qsoDate,
        'time_on': timeOn,
        'band': band,
        'band_rx': bandRx,
        'freq': freq,
        'freq_rx': freqRx,
        'mode': mode,
        'submode': submode,
        'rst_sent': rstSent,
        'rst_rcvd': rstRcvd,
        'comment': comment,
        'sat_name': satName.isEmpty ? null : satName,
        'prop_mode': propMode.isEmpty ? null : propMode,
        'my_gridsquare': myGridsquare.isEmpty ? null : myGridsquare,
        'qsl_sent_date': qslSentDate.isEmpty ? null : qslSentDate,
        'qsl_rcvd_date': qslRcvdDate.isEmpty ? null : qslRcvdDate,
      };
}

class QslCard {
  const QslCard({
    this.qslId = '',
    this.direction = '',
    this.status = '',
    this.date = '',
    this.callsign = '',
    this.stationCallsign = '',
    this.logCount = 0,
    this.logIds = const [],
    this.logs = const [],
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String qslId;
  final String direction;
  final String status;
  final String date;
  final String callsign;
  final String stationCallsign;
  final int logCount;
  final List<int> logIds;
  final List<Map<String, dynamic>> logs;
  final String createdAt;
  final String updatedAt;

  factory QslCard.fromJson(Map<String, dynamic> json) {
    final ids = _asIntList(json['log_ids']);
    final logs = _asMapList(json['logs']);
    final resolvedIds = ids.isNotEmpty
        ? ids
        : logs.map((e) => _asInt(e['id'])).where((id) => id > 0).toList(growable: false);
    return QslCard(
      qslId: _asString(json['qsl_id']),
      direction: _asString(json['direction']),
      status: _asString(json['status']),
      date: _asString(json['date']),
      callsign: _asString(json['callsign'] ?? json['station_callsign']),
      stationCallsign: _asString(json['station_callsign']),
      logCount: _asInt(json['log_count']) == 0 ? (ids.isNotEmpty ? ids.length : logs.length) : _asInt(json['log_count']),
      logIds: resolvedIds,
      logs: logs,
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
    );
  }
}

String _asString(dynamic value) => value == null ? '' : value.toString();

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_asInt).where((e) => e > 0).toList(growable: false);
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
}
