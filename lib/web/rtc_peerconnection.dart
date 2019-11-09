import 'dart:async';
// ignore: uri_does_not_exist
import 'dart:js' as JS;
// ignore: uri_does_not_exist
import 'dart:html' as HTML;
import 'media_stream.dart';
import 'media_stream_track.dart';
import 'rtc_data_channel.dart';
import 'rtc_ice_candidate.dart';
import 'rtc_session_description.dart';
import '../rtc_stats_report.dart';
import '../utils.dart';
import '../enums.dart';

/*
 * Delegate for PeerConnection.
 */
typedef void SignalingStateCallback(RTCSignalingState state);
typedef void IceGatheringStateCallback(RTCIceGatheringState state);
typedef void IceConnectionStateCallback(RTCIceConnectionState state);
typedef void IceCandidateCallback(RTCIceCandidate candidate);
typedef void AddStreamCallback(MediaStream stream);
typedef void RemoveStreamCallback(MediaStream stream);
typedef void AddTrackCallback(MediaStream stream, MediaStreamTrack track);
typedef void RemoveTrackCallback(MediaStream stream, MediaStreamTrack track);
typedef void RTCDataChannelCallback(RTCDataChannel channel);

/*
 *  PeerConnection
 */
class RTCPeerConnection {
  final HTML.RtcPeerConnection _jsPc;

  // public: delegate
  SignalingStateCallback onSignalingState;
  IceGatheringStateCallback onIceGatheringState;
  IceConnectionStateCallback onIceConnectionState;
  IceCandidateCallback onIceCandidate;
  AddStreamCallback onAddStream;
  RemoveStreamCallback onRemoveStream;
  AddTrackCallback onAddTrack;
  RemoveTrackCallback onRemoveTrack;
  RTCDataChannelCallback onDataChannel;
  dynamic onRenegotiationNeeded;

  final Map<String, dynamic> defaultSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  RTCPeerConnection(this._jsPc) {
    _jsPc.onAddStream.listen((mediaStreamEvent) {
      final jsStream = mediaStreamEvent.stream;
      print("onaddstream argument: $jsStream");
      final mediaStream = MediaStream(jsStream);
      if (onAddStream != null) {
        onAddStream(mediaStream);
      }
      jsStream.onAddTrack.listen((mediaStreamTrackEvent) {
        final jsTrack = (mediaStreamTrackEvent as HTML.MediaStreamTrackEvent).track;
        final MediaStreamTrack track = MediaStreamTrack(jsTrack);
        mediaStream.addTrack(track, addToNaitve: false);
        if (onAddTrack != null) {
          onAddTrack(mediaStream, track);
        }
      });
      jsStream.onRemoveTrack.listen((mediaStreamTrackEvent) {
        final jsTrack = (mediaStreamTrackEvent as HTML.MediaStreamTrackEvent).track;
        final MediaStreamTrack track = MediaStreamTrack(jsTrack);
        mediaStream.removeTrack(track, removeFromNaitve: false);
        if (onRemoveTrack != null) {
          onRemoveTrack(mediaStream, track);
        }
      });
    });
    _jsPc.onDataChannel.listen((dataChannelEvent) {
      if (onDataChannel != null) {
        final dc = RTCDataChannel(dataChannelEvent.channel);
        onDataChannel(dc);
      }
    });
    _jsPc.onIceCandidate.listen((iceEvent) {
      if (onIceCandidate != null) {
        onIceCandidate(RTCIceCandidate.fromJs(iceEvent.candidate));
      }
    });
    _jsPc.onIceConnectionStateChange.listen((_) {
      if (onIceConnectionState != null) {
        final state = iceConnectionStateForString(_jsPc.iceConnectionState);
        onIceConnectionState(state);
      }
    });
    JS.JsObject.fromBrowserObject(_jsPc)['onicegatheringstatechange'] = JS.JsFunction.withThis((_) {
      if (onIceGatheringState != null) {
        final state = iceGatheringStateforString(_jsPc.iceGatheringState);
        onIceGatheringState(state);
      }
    });
    _jsPc.onRemoveStream.listen((mediaStreamEvent) {
      final jsStream = mediaStreamEvent.stream;
      final mediaStream = MediaStream(jsStream);
      if (onRemoveStream != null) {
        onRemoveStream(mediaStream);
      }
    });
    _jsPc.onSignalingStateChange.listen((_) {
      if (onSignalingState != null) {
        final state = signalingStateForString(_jsPc.signalingState);
        onSignalingState(state);
      }
    });
    JS.JsObject.fromBrowserObject(_jsPc)['ontrack'] = JS.JsFunction.withThis((_, trackEvent) {
      // trackEvent is JsObject conforming to RTCTrackEvent
      // https://developer.mozilla.org/en-US/docs/Web/API/RTCTrackEvent
      // TODO(rostopira)
      print("ontrack arg: ${trackEvent}");
    });
  }

  Future<void> dispose() {
    _jsPc.close();
    return Future.value();
  }

  Map<String, dynamic> get getConfiguration =>
    throw "Not implemented"; // TODO(rostopira)

  Future<void> setConfiguration(Map<String, dynamic> configuration) {
    _jsPc.setConfiguration(configuration);
    return Future.value();
  }

  Future<RTCSessionDescription> createOffer(Map<String, dynamic> constraints) async {
    final offer = await _jsPc.createOffer(constraints);
    return RTCSessionDescription.fromJs(offer);
  }

  Future<RTCSessionDescription> createAnswer(Map<String, dynamic> constraints) async {
    final answer = await _jsPc.createAnswer(constraints);
    return RTCSessionDescription.fromJs(answer);
  }

  Future<void> addStream(MediaStream stream) {
    _jsPc.addStream(stream.jsStream);
    return Future.value();
  }

  Future<void> removeStream(MediaStream stream) async {
    _jsPc.removeStream(stream.jsStream);
    return Future.value();
  }

  Future<void> setLocalDescription(RTCSessionDescription description) async {
    await _jsPc.setLocalDescription(description.toMap());
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _jsPc.setRemoteDescription(description.toMap());
  }

  Future<RTCSessionDescription> getLocalDescription() async {
    final cld = JS.JsObject.fromBrowserObject(_jsPc)['currentLocalDescription'];
    return RTCSessionDescription.fromJsObj(cld);
  }

  Future<RTCSessionDescription> getRemoteDescription() async {
    final cld = JS.JsObject.fromBrowserObject(_jsPc)['currentRemoteDescription'];
    return RTCSessionDescription.fromJsObj(cld);
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    await _jsPc.addIceCandidate(candidate.toJs(), () {
      print("Ice candidate added");
    }, (domException) {
      print(domException);
    });
  }

  Future<List<StatsReport>> getStats(MediaStreamTrack track) async {
    final stats = await _jsPc.getStats();
    List<StatsReport> report = [];
    stats.forEach((key, value) {
      report.add(
          StatsReport(value['id'], value['type'], value['timestamp'], value));
    });
    return report;
  }

  List<MediaStream> getLocalStreams() =>
    _jsPc.getLocalStreams().map((jsStream) => MediaStream(jsStream)).toList();

  List<MediaStream> getRemoteStreams() =>
    _jsPc.getRemoteStreams().map((jsStream) => MediaStream(jsStream)).toList();

  Future<RTCDataChannel> createDataChannel(String label, RTCDataChannelInit dataChannelDict) {
    final map = dataChannelDict.toMap();
    if (dataChannelDict.binaryType == 'binary')
      map['binaryType'] = 'arraybuffer'; // Avoid Blob in data channel
    final jsDc = _jsPc.createDataChannel(label, map);
    return Future.value(RTCDataChannel(jsDc));
  }

  Future<Null> close() async {
    _jsPc.close();
    return Future.value();
  }

}
