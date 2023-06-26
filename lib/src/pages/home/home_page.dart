import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as RTC;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_app/src/pages/home/widgets/remote_view_card.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../services/socket_emit.dart';

bool isConnected = false;
bool isAudioOn = true, isVideoOn = true;
String roomId = "";
Map<String, dynamic> configuration = {
  'iceServers': [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',

      ]
    },
    /*
    {
      "urls": "turn:turn.jacknathan.tk:3478",
      "username": "ducanhzed",
      "credential": "1507200a",
    },

     */
  ],
  'sdpSemantics': "unified-plan",
};

late Socket socket;

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver{
  List<Map<String, dynamic>> socketIdRemotes = [];
  RTC.RTCPeerConnection? _peerConnection;
  RTC.MediaStream? _localStream;
  final RTC.RTCVideoRenderer _localRenderer = RTC.RTCVideoRenderer();
  bool _isSend = false;
  bool _isFrontCamera = true;
  bool get isiOS => foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;
  bool get isAndroid => foundation.defaultTargetPlatform == foundation.TargetPlatform.android;
  final roomIdTextEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    roomIdTextEditingController.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        log('FinAppRootHome resumed');
        break;
      case AppLifecycleState.inactive:
        log('FinAppRootHome inactive');
        break;
      case AppLifecycleState.detached:
        log('FinAppRootHome detached');
        // DO SOMETHING!
        break;
      case AppLifecycleState.paused:
        log('FinAppRootHome paused');
        break;
      default:
        break;
    }
  }

  _init(){
    roomIdTextEditingController.text = "";
    initRenderers();
    _createPeerConnection().then(
          (pc) async {
        _peerConnection = pc;
        _localStream = await _getUserMedia();
        _localStream?.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, _localStream!);
        });
        isConnected = true;
        setState(() {});
      },
    );
    connectAndListen();
    setState(() {});
  }

  _switchCamera() async {
    final localStream = _localStream;
    if (localStream != null) {
      bool value = await localStream.getVideoTracks()[0].switchCamera();
      while (value == _isFrontCamera) {
        value = await localStream.getVideoTracks()[0].switchCamera();
      }
      _isFrontCamera = value;
      setState(() {});
    }
  }

  _createPeerConnectionAnswer(socketId) async {
    RTC.RTCPeerConnection pc = await RTC.createPeerConnection(configuration);

    pc.onTrack = (track) {
      int index = socketIdRemotes.indexWhere((item) => item['socketId'] == socketId);
      socketIdRemotes[index]['stream'].srcObject = track.streams[0];
      setState(() {});
    };

    pc.onRenegotiationNeeded = () {
      _createOfferForReceive(socketId);
    };

    return pc;
  }

  void connectAndListen() async {
    var urlConnectSocket = 'http://192.168.0.22:5000';
    socket = io(urlConnectSocket, OptionBuilder().enableForceNew().setTransports(['websocket']).build());
    socket.connect();
    socket.onConnect((_) {
      socket.on('NEW-PEER-SSC', (data) async {
        String newUser = data['socketId'];
        RTC.RTCVideoRenderer stream = RTC.RTCVideoRenderer();
        await stream.initialize();
        setState(() {
          socketIdRemotes.add({
            'socketId': newUser,
            'pc': null,
            'stream': stream,
          });
        });
        _createPeerConnectionAnswer(newUser).then((pcRemote) {
          socketIdRemotes[socketIdRemotes.length - 1]['pc'] = pcRemote;
          socketIdRemotes[socketIdRemotes.length - 1]['pc'].addTransceiver(
            kind: RTC.RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTC.RTCRtpTransceiverInit(
              direction: RTC.TransceiverDirection.RecvOnly,
            ),
          );
        });
      });

      socket.on('SEND-SSC', (data) {
        List<String> listSocketId = (data['sockets'] as List<dynamic>).map((e) => e.toString()).toList();
        listSocketId.asMap().forEach((index, user) async {
          RTC.RTCVideoRenderer stream = RTC.RTCVideoRenderer();
          await stream.initialize();
          setState(() {
            socketIdRemotes.add({
              'socketId': user,
              'pc': null,
              'stream': stream,
            });
          });
          _createPeerConnectionAnswer(user).then((pcRemote) {
            socketIdRemotes[index]['pc'] = pcRemote;
            socketIdRemotes[index]['pc'].addTransceiver(
              kind: RTC.RTCRtpMediaType.RTCRtpMediaTypeVideo,
              init: RTC.RTCRtpTransceiverInit(
                direction: RTC.TransceiverDirection.RecvOnly,
              ),
            );
          });
        });

        _setRemoteDescription(data['sdp']);
      });

      socket.on('RECEIVE-SSC', (data) {
        int index = socketIdRemotes.indexWhere(
          (element) => element['socketId'] == data['socketId'],
        );
        if (index != -1) {
          _setRemoteDescriptionForReceive(index, data['sdp']);
        }
      });
    });

    socket.on('OUT-PEER-SSC', (data) {
      String outUser = data['socketId'];
      int index = socketIdRemotes.indexWhere((item) => item['socketId'] == outUser);
      if (index != -1) {
        socketIdRemotes.removeAt(index);
        setState(() {});
      }
    });

    socket.onDisconnect((_){

    });
  }

  initRenderers() async {
    await _localRenderer.initialize();
  }

  void _setRemoteDescription(sdp) async {
    RTC.RTCSessionDescription description = RTC.RTCSessionDescription(sdp, 'answer');
    await _peerConnection?.setRemoteDescription(description);
  }

  void _setRemoteDescriptionForReceive(indexSocket, sdp) async {
    RTC.RTCSessionDescription description = RTC.RTCSessionDescription(sdp, 'answer');
    await socketIdRemotes[indexSocket]['pc'].setRemoteDescription(description);
  }

  _createOffer() async {
    RTC.RTCSessionDescription? description = await _peerConnection?.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': true,
    });
    _peerConnection?.setLocalDescription(description!);
    var session = parse(description!.sdp.toString());
    String sdp = write(session, null);
    await sendSdpForBroadcast(sdp);
  }

  _createOfferForReceive(String socketId) async {
    int index = socketIdRemotes.indexWhere((item) => item['socketId'] == socketId);
    if (index != -1) {
      RTC.RTCSessionDescription description = await socketIdRemotes[index]['pc'].createOffer();
      socketIdRemotes[index]['pc'].setLocalDescription(description);
      var session = parse(description.sdp.toString());
      String sdp = write(session, null);
      await sendSdpOnlyReceive(sdp, socketId);
    }
  }

  _createPeerConnection() async {
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    RTC.RTCPeerConnection pc = await RTC.createPeerConnection(configuration, offerSdpConstraints);

    pc.onRenegotiationNeeded = () {
      if (!_isSend) {
        _isSend = true;
        _createOffer();
      }
    };
    return pc;
  }

  Future sendSdpForBroadcast(
    String sdp,
  ) async {
    SocketEmit().sendSdpForBroadcase(sdp, roomId);
  }

  Future sendSdpOnlyReceive(
    String sdp,
    String socketId,
  ) async {
    SocketEmit().sendSdpForReceive(sdp, socketId, roomId);
  }

  Future sendOut() async {
    await SocketEmit().sendSdpForOut(roomId);
    _endCall();
    if(!isiOS){
      if(isAndroid) {
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      } else {
        socketIdRemotes.clear();
        setState(() {});
      }

    }else{
      socketIdRemotes.clear();
      setState(() {});
    }
  }

  _getUserMedia() async {
    RTC.MediaStream stream = await RTC.navigator.mediaDevices.getUserMedia({
      'audio': {
        'sampleRate': 16000,
        'sampleSize': 16,
        'volume': 0.3,
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': true
    },
      'video': {
        'facingMode': 'user',
      },
    });


    _localRenderer.srcObject = stream;
    setState(() {});

    return stream;
  }

  _endCall() {
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;

    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double w = MediaQuery.of(context).size.width - MediaQuery.of(context).padding.left - MediaQuery.of(context).padding.right;
    double h = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        toolbarHeight: 60,
        elevation: 5,
        title:  const Text('META CALL', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              children: [
                !isConnected
                    ? Container(
                  color: Colors.black,
                  width: w,
                  height: 200,
                  child: socketIdRemotes.isEmpty
                      ? Container()
                      : RemoteViewCard(
                          remoteRenderer: socketIdRemotes[0]['stream'],
                        ),
                ) : Container(
                  color: Colors.black,
                  width: w,
                  height: h-60,
                  child: socketIdRemotes.isEmpty
                      ? Container()
                      : RemoteViewCard(
                    remoteRenderer: socketIdRemotes[0]['stream'],
                  ),
                ),
                Positioned(
                  bottom: 20.0,
                  left: 12.0,
                  right: 0,
                  child: Container(
                    color: Colors.transparent,
                    width: size.width,
                    height: size.width * .35,
                    child: socketIdRemotes.length < 2
                        ? Container()
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: socketIdRemotes.length - 1,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(right: 6.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(
                                    color: Colors.amberAccent,
                                    width: 2.0,
                                  ),
                                ),
                                child: RemoteViewCard(
                                  remoteRenderer: socketIdRemotes[index + 1]['stream'],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 45.0,
                  left: 15.0,
                  child: Row(
                    children: [
                      !isConnected
                          ? Container(
                              height: 150,
                              width: w-30,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                               children: [
                                 TextField(
                                   style: const TextStyle(color: Colors.grey),
                                   controller: roomIdTextEditingController,
                                   textAlign: TextAlign.center,
                                   cursorColor: Colors.grey,
                                   decoration: InputDecoration(
                                     focusedBorder: OutlineInputBorder(
                                         borderSide: const BorderSide(color: Colors.amber),
                                         borderRadius: BorderRadius.circular(10.0)
                                     ),
                                     enabledBorder: OutlineInputBorder(
                                       borderSide: const BorderSide(color: Colors.amber),
                                       borderRadius: BorderRadius.circular(10.0)
                                     ),
                                     hintText: "방 ID",
                                     hintStyle: const TextStyle(color: Colors.grey),
                                     alignLabelWithHint: true,
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(20.0),
                                     ),
                                   ),
                                 ),
                                 SizedBox(height: 5.0),
                                 ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                       fixedSize: Size(w-30,60),
                                       shape: RoundedRectangleBorder( //to set border radius to button
                                           borderRadius: BorderRadius.circular(10)
                                       ),
                                       backgroundColor: Colors.amber
                                   ),
                                   child: const Text(
                                     "입장하기",
                                     style: TextStyle(
                                       fontSize: 14,
                                       color: Colors.black,
                                     ),
                                   ),
                                   onPressed: () {
                                     if(roomIdTextEditingController.text.trim() != ""){
                                       roomId = roomIdTextEditingController.text;
                                       _init();
                                     }
                                   },
                                 )
                               ],
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.cover,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(6.0)),
                                  border: Border.all(color: Colors.amberAccent, width: 2.0),
                                ),
                                child: RemoteViewCard(
                                  remoteRenderer: _localRenderer,
                                ),
                              ),
                            ),
                      !isConnected
                          ? Container() : SizedBox(width: 8.0),
                      !isConnected
                          ? Container() : Column(
                        children: [
                          GestureDetector(
                            onTap: () => _switchCamera(),
                            child: Container(
                              height: size.width * .125,
                              width: size.width * .125,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent, width: 2.0),
                                color: Colors.amberAccent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.switch_camera,
                                color: Colors.black,
                                size: size.width / 18.0,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          GestureDetector(
                            onTap: () => _toggleMic(),
                            child: Container(
                              height: size.width * .125,
                              width: size.width * .125,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent, width: 2.0),
                                color: Colors.amberAccent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(isAudioOn ? Icons.mic : Icons.mic_off,
                                color: Colors.black,
                                size: size.width / 18.0)
                            ),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          GestureDetector(
                            onTap: () => sendOut(),
                            child: Container(
                                height: size.width * .125,
                                width: size.width * .125,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2.0),
                                  color: Colors.black,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.logout,
                                    color: Colors.amberAccent,
                                    size: size.width / 18.0)
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
